#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP="build/ClaudePet.app"
rm -rf "${APP}"
mkdir -p "${APP}/Contents/MacOS" "${APP}/Contents/Resources"

swiftc -O -o "${APP}/Contents/MacOS/ClaudePet" Sources/main.swift \
  -framework AppKit -framework QuartzCore

cat > "${APP}/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>ClaudePet</string>
    <key>CFBundleDisplayName</key><string>小 Claude</string>
    <key>CFBundleExecutable</key><string>ClaudePet</string>
    <key>CFBundleIdentifier</key><string>local.claude.pet</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSUIElement</key><true/>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSMinimumSystemVersion</key><string>12.0</string>
</dict>
</plist>
PLIST

codesign --force --deep -s - "${APP}" >/dev/null 2>&1 || true
echo "built: ${APP}"
