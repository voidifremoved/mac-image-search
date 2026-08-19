#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalImageSearch"
APP_PATH="build/${APP_NAME}.app"
DIST_DIR="dist"
ARCHIVE_PATH="${DIST_DIR}/${APP_NAME}-macOS.zip"

if [[ ! -d "${APP_PATH}" ]]; then
    echo "Missing ${APP_PATH}; run scripts/bundle_app.sh first." >&2
    exit 1
fi

mkdir -p "${DIST_DIR}"
rm -f "${ARCHIVE_PATH}" "${ARCHIVE_PATH}.sha256"
ditto -c -k --sequesterRsrc --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
shasum -a 256 "${ARCHIVE_PATH}" > "${ARCHIVE_PATH}.sha256"

echo "Created ${ARCHIVE_PATH}"
