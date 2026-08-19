#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalImageSearch"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "Building release binary..."
swift build -c release

echo "Creating .app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"

echo "Writing Info.plist..."
cat << 'PLIST' > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LocalImageSearch</string>
    <key>CFBundleIdentifier</key>
    <string>com.localimagesearch.app</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Local Image Search</string>
    <key>CFBundleDisplayName</key>
    <string>Local Image Search</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Signing ad-hoc application bundle..."
codesign --force --deep --sign - "${BUNDLE_DIR}"

echo "Standalone app created and signed at: ${BUNDLE_DIR}"
echo "You can launch it with: open ${BUNDLE_DIR}"
