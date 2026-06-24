# Did I Leave the Oven On

A simple Mac app for backing up folders to an external drive — with progress notifications so you actually know it's working.

## What it does

1. You pick a folder to back up and a destination (e.g. an external drive)
2. Your choices are saved — next time it's just one click to sync
3. It syncs new and updated files only — unchanged files are skipped
4. A notification appears at the halfway point so you know it's still running
5. When done, it verifies the sync was 1:1 accurate and tells you it's safe to eject

If your saved destination drive isn't plugged in, it detects that and lets you pick a new one instead of failing silently.

Built with pure bash + osascript. No Python, no dependencies, no Xcode required.

## Install

1. Download and unzip this repo
2. Open Terminal, `cd` into the folder, and run:

```bash
bash install.sh
```

The app will appear in your `/Applications` folder. Launch it from Spotlight or Finder like any other app.

## Usage

- **First run:** you'll be prompted to pick a source folder and destination
- **Every run after:** a single dialog shows your saved folders — hit **Sync** to go, or **Change** to pick different folders
- **Drive not plugged in:** if the saved destination isn't found, it automatically asks you to pick a new one

Your saved folder preferences are stored at `~/.config/did-i-leave-the-oven-on/config`.

## Update

To install a newer version, just run `bash install.sh` again — it overwrites the existing app.

## Requirements

- macOS 10.10 or later
- No additional software needed
