# Did I Leave the Oven On

A simple Mac app for backing up folders to an external drive — with progress notifications so you actually know it's working.

## What it does

1. You pick a folder to back up
2. You pick a destination (e.g. an external drive)
3. It syncs new and updated files only — unchanged files are skipped
4. Notifications appear as files sync so you can see progress in real time
5. When done, it verifies the sync was 1:1 accurate and tells you it's safe to eject

Built with pure bash + osascript. No Python, no dependencies, no Xcode required.

## Install

1. Download and unzip this repo
2. Open Terminal and run:

```bash
cd "Did I Leave the Oven On"
bash install.sh
```

The app will appear in your `/Applications` folder. Launch it from Spotlight or Finder like any other app.

## Update

To install a newer version, just run `bash install.sh` again — it overwrites the existing app.

## Requirements

- macOS 10.10 or later
- No additional software needed
