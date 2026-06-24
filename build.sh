#!/bin/bash
# Builds the .app bundle from Swift source files.
# Requires Swift (comes with Xcode Command Line Tools: xcode-select --install)

APP_NAME="Did I Leave the Oven On"
APP_BUNDLE="${APP_NAME}.app"

echo "Building ${APP_NAME}..."

rm -rf "$APP_BUNDLE"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

swiftc Sources/*.swift \
    -framework AppKit \
    -framework Foundation \
    -framework UserNotifications \
    -o "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"

if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

cp Info.plist "${APP_BUNDLE}/Contents/Info.plist"
[ -f AppIcon.icns ] && cp AppIcon.icns "${APP_BUNDLE}/Contents/Resources/AppIcon.icns"

xattr -cr "$APP_BUNDLE" 2>/dev/null

echo "✅ Built ${APP_BUNDLE}"
