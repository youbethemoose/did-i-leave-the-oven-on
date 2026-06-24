# Did I Leave the Oven On

A Mac menu bar app for backing up folders to an external drive. Lives quietly in your menu bar — click it to sync, see progress, and know when it's safe to eject.

## What it does

- Sits in your menu bar — click to sync anytime
- Back up one or multiple folders to a single destination drive
- Remembers your folders — one click after first setup
- Only copies new or changed files, so it's fast and doesn't waste drive space
- Prevents your Mac from sleeping while syncing
- Shows live progress in the menu bar dropdown
- Notifies you at the halfway point and when the sync is verified complete
- Detects if your destination drive isn't plugged in and lets you pick a new one

## Install

1. Go to [Releases](https://github.com/youbethemoose/did-i-leave-the-oven-on/releases) and download **Did.I.Leave.the.Oven.On.zip**
2. Unzip and drag the app to your Applications folder
3. First time only: right-click the app → **Open** (macOS security prompt for apps distributed outside the App Store)

## Build from source

Requires Swift command line tools (`xcode-select --install` — no full Xcode needed):

```bash
git clone https://github.com/youbethemoose/did-i-leave-the-oven-on
cd did-i-leave-the-oven-on
bash build.sh
```

## Requirements

- macOS 12 or later
