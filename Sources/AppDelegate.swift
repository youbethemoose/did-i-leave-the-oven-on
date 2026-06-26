import AppKit
import UserNotifications

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var syncManager: SyncManager!

    // Menu items
    var foldersMenuItem: NSMenuItem!
    var lastSyncMenuItem: NSMenuItem!
    var progressMenuItem: NSMenuItem!
    var syncNowMenuItem: NSMenuItem!
    var changeFoldersMenuItem: NSMenuItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            if !granted {
                print("Notification permission denied")
            }
        }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setIcon(.idle)

        syncManager = SyncManager()
        syncManager.delegate = self

        buildMenu()
        updateMenu()
    }

    // MARK: - Icon states

    enum IconState { case idle, syncing, done, error }

    func setIcon(_ state: IconState) {
        guard let button = statusItem.button else { return }
        switch state {
        case .idle:
            button.image = NSImage(systemSymbolName: "externaldrive", accessibilityDescription: nil)
        case .syncing:
            button.image = NSImage(systemSymbolName: "arrow.triangle.2.circlepath", accessibilityDescription: nil)
        case .done:
            button.image = NSImage(systemSymbolName: "externaldrive.badge.checkmark", accessibilityDescription: nil)
        case .error:
            button.image = NSImage(systemSymbolName: "externaldrive.badge.exclamationmark", accessibilityDescription: nil)
        }
        button.image?.isTemplate = true
    }

    // MARK: - Menu

    func buildMenu() {
        let menu = NSMenu()

        foldersMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        foldersMenuItem.isEnabled = false
        menu.addItem(foldersMenuItem)

        lastSyncMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        lastSyncMenuItem.isEnabled = false
        menu.addItem(lastSyncMenuItem)

        progressMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        progressMenuItem.isEnabled = false
        progressMenuItem.isHidden = true
        menu.addItem(progressMenuItem)

        menu.addItem(.separator())

        syncNowMenuItem = NSMenuItem(title: "Sync Now", action: #selector(syncNow), keyEquivalent: "s")
        syncNowMenuItem.target = self
        menu.addItem(syncNowMenuItem)

        changeFoldersMenuItem = NSMenuItem(title: "Change Folders…", action: #selector(changeFolders), keyEquivalent: "")
        changeFoldersMenuItem.target = self
        menu.addItem(changeFoldersMenuItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    func updateMenu() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let sm = self.syncManager!

            // Folders line
            if sm.sources.isEmpty {
                self.foldersMenuItem.title = "No folders configured"
            } else {
                let names = sm.sources.map { URL(fileURLWithPath: $0).lastPathComponent }
                self.foldersMenuItem.title = names.joined(separator: "  ·  ")
            }

            // Last sync line
            if let date = sm.lastSyncDate {
                let f = RelativeDateTimeFormatter()
                f.unitsStyle = .full
                self.lastSyncMenuItem.title = "Last sync: \(f.localizedString(for: date, relativeTo: Date()))"
            } else {
                self.lastSyncMenuItem.title = "Never synced"
            }

            // Sync button
            self.syncNowMenuItem.isEnabled = !sm.isSyncing && !sm.sources.isEmpty
            self.syncNowMenuItem.title = sm.isSyncing ? "Syncing…" : "Sync Now"
            self.changeFoldersMenuItem.isEnabled = !sm.isSyncing
        }
    }

    // MARK: - Actions

    @objc func syncNow() {
        guard !syncManager.isSyncing else { return }
        if syncManager.sources.isEmpty || syncManager.destination == nil {
            changeFolders()
            return
        }
        syncManager.startSync()
    }

    @objc func changeFolders() {
        guard !syncManager.isSyncing else { return }
        syncManager.pickFolders { [weak self] in
            self?.updateMenu()
        }
    }

    // MARK: - Notifications

    func notify(title: String, body: String, persistent: Bool = false) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        if persistent {
            content.interruptionLevel = .timeSensitive
        }
        let req = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(req)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension AppDelegate: UNUserNotificationCenterDelegate {
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler handler: @escaping (UNNotificationPresentationOptions) -> Void) {
        handler([.banner, .sound])
    }
}

// MARK: - SyncManagerDelegate

extension AppDelegate: SyncManagerDelegate {
    func syncDidStart() {
        DispatchQueue.main.async { self.setIcon(.syncing) }
        updateMenu()
    }

    func syncDidProgress(done: Int, total: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let pct = total > 0 ? (done * 100 / total) : 0
            self.progressMenuItem.title = "  \(done) of \(total) files (\(pct)%)"
            self.progressMenuItem.isHidden = false
        }
    }

    func syncDidReachHalfway() {
        notify(title: "Did I Leave the Oven On", body: "Halfway there — still syncing…")
    }

    func syncDidComplete(fileCount: Int, destination: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setIcon(.done)
            self.progressMenuItem.isHidden = true
        }
        updateMenu()
        let destName = URL(fileURLWithPath: destination).lastPathComponent
        notify(
            title: "✅ Sync Complete & Verified",
            body: "All \(fileCount) files synced 1:1 to \(destName). Safe to eject.",
            persistent: true
        )
        // Reset icon to idle after a few seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { [weak self] in
            self?.setIcon(.idle)
        }
    }

    func syncDidFail(folder: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.setIcon(.error)
            self.progressMenuItem.isHidden = true
        }
        updateMenu()
        notify(title: "⚠️ Sync Failed", body: "Error syncing \(folder). Check source and destination.")
    }
}
