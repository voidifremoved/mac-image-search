# Release & Verification Guide

## Build & Test
Run the verification script:
```bash
./scripts/verify.sh
```

## App Sandbox & Entitlements
- `com.apple.security.app-sandbox`: Enabled
- `com.apple.security.files.user-selected.read-only`: Enabled
- `com.apple.security.files.bookmarks.app-scope`: Enabled
- `com.apple.security.network.client`: Enabled

## Signing & Notarization
To archive and notarize for Developer ID distribution:
```bash
xcodebuild -scheme LocalImageSearch -configuration Release archive -archivePath build/LocalImageSearch.xcarchive
xcrun notarytool submit build/LocalImageSearch.zip --keychain-profile "Developer-ID" --wait
xcrun stapler staple "LocalImageSearch.app"
```
