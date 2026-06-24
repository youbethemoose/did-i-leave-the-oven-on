#!/bin/bash

APP_NAME="Did I Leave the Oven On"
APP_DIR="/Applications/${APP_NAME}.app"
BUNDLE_MACOS="${APP_DIR}/Contents/MacOS"
BUNDLE_RESOURCES="${APP_DIR}/Contents/Resources"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Installing ${APP_NAME}..."

# ── Build bundle structure ──
mkdir -p "$BUNDLE_MACOS" "$BUNDLE_RESOURCES"

# ── Copy & make executable the main script ──
cp "$SCRIPT_DIR/sync.sh" "$BUNDLE_MACOS/${APP_NAME}"
chmod +x "$BUNDLE_MACOS/${APP_NAME}"

# ── Info.plist ──
cat > "${APP_DIR}/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>com.user.didileavetheovenon</string>
    <key>CFBundleVersion</key>
    <string>1.1</string>
    <key>CFBundleShortVersionString</key>
    <string>1.1</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>LSMinimumSystemVersion</key>
    <string>10.10</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSUserNotificationAlertStyle</key>
    <string>alert</string>
</dict>
</plist>
PLIST

# ── PkgInfo ──
echo -n "APPL????" > "${APP_DIR}/Contents/PkgInfo"

# ── Copy icon if present ──
if [ -f "$SCRIPT_DIR/AppIcon.icns" ]; then
    cp "$SCRIPT_DIR/AppIcon.icns" "$BUNDLE_RESOURCES/AppIcon.icns"
    /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string AppIcon" "${APP_DIR}/Contents/Info.plist" 2>/dev/null || \
    /usr/libexec/PlistBuddy -c "Set :CFBundleIconFile AppIcon" "${APP_DIR}/Contents/Info.plist"
fi

# ── Clear quarantine so macOS doesn't block it ──
xattr -cr "$APP_DIR" 2>/dev/null

echo "✅ Installed to /Applications/${APP_NAME}.app"
echo "   You can now launch it from Spotlight or your Applications folder."
