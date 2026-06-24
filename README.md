# Did I Leave the Oven On

A simple Mac app for backing up folders to an external drive — with progress notifications so you actually know it's working.

## What it does

1. You pick one or more folders to back up and a destination drive
2. Your choices are saved — next time it's just one click to sync
3. It syncs new and updated files only — unchanged files are skipped, no double space usage
4. Prevents your Mac from sleeping while the sync is running
5. A notification appears at the halfway point so you know it's still running
6. When done, a persistent alert confirms the sync was 1:1 accurate and tells you it's safe to eject

If your saved destination drive isn't plugged in, it detects that and lets you pick a new one instead of failing silently.

Built with pure bash + osascript. No Python, no dependencies, no Xcode required.

## Install

### Option 1 — App (easiest)
1. Go to the [Releases](https://github.com/youbethemoose/did-i-leave-the-oven-on/releases) page and download **Did I Leave the Oven On (App)**
2. Unzip it and drag the app to your Applications folder
3. First time only: right-click the app → **Open** (macOS will warn it's from the internet — this is normal for apps distributed outside the App Store)

### Option 2 — Terminal Installer
1. Download and unzip this repo
2. Open Terminal, `cd` into the folder, and run:

```bash
bash install.sh
```

The app will appear in your `/Applications` folder with no extra steps needed.

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
