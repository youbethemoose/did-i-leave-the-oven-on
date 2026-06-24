import Foundation
import AppKit

protocol SyncManagerDelegate: AnyObject {
    func syncDidStart()
    func syncDidProgress(done: Int, total: Int)
    func syncDidReachHalfway()
    func syncDidComplete(fileCount: Int, destination: String)
    func syncDidFail(folder: String)
}

class SyncManager {
    weak var delegate: SyncManagerDelegate?

    var sources: [String] = []
    var destination: String?
    var isSyncing = false
    var lastSyncDate: Date?

    private let configURL: URL
    private var caffeinate: Process?

    init() {
        let dir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/did-i-leave-the-oven-on")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        configURL = dir.appendingPathComponent("config")
        loadConfig()
    }

    // MARK: - Config

    func loadConfig() {
        guard let content = try? String(contentsOf: configURL) else { return }
        sources = []
        destination = nil
        for line in content.components(separatedBy: "\n") {
            if line.hasPrefix("SOURCE=") { sources.append(String(line.dropFirst(7))) }
            else if line.hasPrefix("DEST=") { destination = String(line.dropFirst(5)) }
            else if line.hasPrefix("LAST_SYNC="), let ts = Double(line.dropFirst(10)) {
                lastSyncDate = Date(timeIntervalSince1970: ts)
            }
        }
    }

    func saveConfig() {
        var lines = sources.map { "SOURCE=\($0)" }
        if let d = destination { lines.append("DEST=\(d)") }
        if let date = lastSyncDate { lines.append("LAST_SYNC=\(date.timeIntervalSince1970)") }
        try? lines.joined(separator: "\n").write(to: configURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Folder picking

    func pickFolders(completion: @escaping () -> Void) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            let destPanel = NSOpenPanel()
            destPanel.message = "Select the destination drive or folder:"
            destPanel.canChooseFiles = false
            destPanel.canChooseDirectories = true
            NSApp.activate(ignoringOtherApps: true)
            guard destPanel.runModal() == .OK, let destURL = destPanel.url else { return }
            self.destination = destURL.path

            self.sources = []
            self.pickNextSource(completion: completion)
        }
    }

    private func pickNextSource(completion: @escaping () -> Void) {
        let panel = NSOpenPanel()
        panel.message = "Select a folder to back up:"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        NSApp.activate(ignoringOtherApps: true)

        guard panel.runModal() == .OK, let url = panel.url else {
            if sources.isEmpty { return }
            saveConfig()
            completion()
            return
        }
        sources.append(url.path)

        let alert = NSAlert()
        alert.messageText = "Add another folder to this backup?"
        alert.addButton(withTitle: "Add Another")
        alert.addButton(withTitle: "Done")
        NSApp.activate(ignoringOtherApps: true)

        if alert.runModal() == .alertFirstButtonReturn {
            pickNextSource(completion: completion)
        } else {
            saveConfig()
            completion()
        }
    }

    // MARK: - Sync

    func startSync() {
        guard !isSyncing, let dest = destination, !sources.isEmpty else { return }
        isSyncing = true
        delegate?.syncDidStart()

        caffeinate = Process()
        caffeinate?.launchPath = "/usr/bin/caffeinate"
        caffeinate?.arguments = ["-i"]
        try? caffeinate?.run()

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.runSync(destination: dest)
        }
    }

    private func countFiles(at path: String) -> Int {
        guard let enumerator = FileManager.default.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return 0 }
        return enumerator.reduce(0) { count, item in
            guard let url = item as? URL,
                  let vals = try? url.resourceValues(forKeys: [.isRegularFileKey]),
                  vals.isRegularFile == true else { return count }
            return count + 1
        }
    }

    private func runRsync(source: String, destination: String) -> Bool {
        let p = Process()
        p.launchPath = "/usr/bin/rsync"
        p.arguments = ["-a", "--update", "--modify-window=2", source, destination]
        try? p.run()
        p.waitUntilExit()
        return p.terminationStatus == 0
    }

    private func verifyRsync(source: String, destFolder: String) -> Int {
        let p = Process()
        p.launchPath = "/usr/bin/rsync"
        p.arguments = ["-a", "--dry-run", "--itemize-changes", "--modify-window=2",
                       source + "/", destFolder + "/"]
        let pipe = Pipe()
        p.standardOutput = pipe
        try? p.run()
        p.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.components(separatedBy: "\n").filter { $0.hasPrefix(">f") || $0.hasPrefix("<f") }.count
    }

    private func runSync(destination: String) {
        let totalFiles = sources.reduce(0) { $0 + countFiles(at: $1) }
        guard totalFiles > 0 else {
            finish(success: false, folder: "source folders", destination: destination)
            return
        }

        let halfway = totalFiles / 2
        var halfwayNotified = false
        var totalDone = 0

        for src in sources {
            let folderName = URL(fileURLWithPath: src).lastPathComponent
            let destFolder = (destination as NSString).appendingPathComponent(folderName)

            guard runRsync(source: src, destination: destination) else {
                finish(success: false, folder: folderName, destination: destination)
                return
            }

            // Monitor progress after rsync (for small syncs it finishes fast; this catches large ones)
            if !halfwayNotified {
                let done = totalDone + countFiles(at: destFolder)
                delegate?.syncDidProgress(done: done, total: totalFiles)
                if done >= halfway {
                    halfwayNotified = true
                    delegate?.syncDidReachHalfway()
                }
            }

            totalDone += countFiles(at: destFolder)
        }

        // Flush
        let sync = Process()
        sync.launchPath = "/bin/sync"
        try? sync.run()
        sync.waitUntilExit()

        // Verify
        var totalMismatches = 0
        var totalDestCount = 0
        for src in sources {
            let folderName = URL(fileURLWithPath: src).lastPathComponent
            let destFolder = (destination as NSString).appendingPathComponent(folderName)
            totalMismatches += verifyRsync(source: src, destFolder: destFolder)
            totalDestCount += countFiles(at: destFolder)
        }

        lastSyncDate = Date()
        saveConfig()

        finish(success: totalMismatches == 0, folder: "verification", destination: destination, fileCount: totalDestCount)
    }

    private func finish(success: Bool, folder: String, destination: String, fileCount: Int = 0) {
        caffeinate?.terminate()
        caffeinate = nil
        DispatchQueue.main.async { [weak self] in
            self?.isSyncing = false
            if success {
                self?.delegate?.syncDidComplete(fileCount: fileCount, destination: destination)
            } else {
                self?.delegate?.syncDidFail(folder: folder)
            }
        }
    }
}
