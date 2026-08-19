#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalImageSearch"
BUNDLE_IDENTIFIER="com.localimagesearch.app"
BUNDLE_DIR="build/${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
APP_VERSION="${APP_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"
SIGNING_IDENTITY="${SIGNING_IDENTITY:--}"
ENTITLEMENTS_PATH="LocalImageSearchApp/LocalImageSearch.entitlements"

echo "Building release binary..."
if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
    ARM_SCRATCH=".build/release-arm64"
    INTEL_SCRATCH=".build/release-x86_64"
    swift build -c release --disable-sandbox --triple arm64-apple-macosx14.0 --scratch-path "${ARM_SCRATCH}"
    swift build -c release --disable-sandbox --triple x86_64-apple-macosx14.0 --scratch-path "${INTEL_SCRATCH}"
    ARM_BIN="$(swift build -c release --disable-sandbox --triple arm64-apple-macosx14.0 --scratch-path "${ARM_SCRATCH}" --show-bin-path)/${APP_NAME}"
    INTEL_BIN="$(swift build -c release --disable-sandbox --triple x86_64-apple-macosx14.0 --scratch-path "${INTEL_SCRATCH}" --show-bin-path)/${APP_NAME}"
else
    swift build -c release --disable-sandbox
    BIN_PATH="$(swift build -c release --disable-sandbox --show-bin-path)/${APP_NAME}"
fi

echo "Creating .app bundle structure..."
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

if [[ "${BUILD_UNIVERSAL:-0}" == "1" ]]; then
    lipo -create "${ARM_BIN}" "${INTEL_BIN}" -output "${MACOS_DIR}/${APP_NAME}"
else
    cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
fi

echo "Writing Info.plist..."
cat << PLIST > "${CONTENTS_DIR}/Info.plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>LocalImageSearch</string>
    <key>CFBundleIdentifier</key>
    <string>${BUNDLE_IDENTIFIER}</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>Local Image Search</string>
    <key>CFBundleDisplayName</key>
    <string>Local Image Search</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>${APP_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "Signing application bundle with identity: ${SIGNING_IDENTITY}"
SIGN_ARGS=(--force --deep --sign "${SIGNING_IDENTITY}" --entitlements "${ENTITLEMENTS_PATH}")
if [[ "${SIGNING_IDENTITY}" != "-" ]]; then
    SIGN_ARGS+=(--options runtime --timestamp)
fi
codesign "${SIGN_ARGS[@]}" "${BUNDLE_DIR}"
codesign --verify --deep --strict "${BUNDLE_DIR}"

echo "Standalone app created and signed at: ${BUNDLE_DIR}"
echo "You can launch it with: open ${BUNDLE_DIR}"
