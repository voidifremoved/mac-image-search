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

## Automated GitHub builds

`.github/workflows/build-and-release.yml` runs on pull requests, pushes to `main`, manual dispatches, and version tags.

- Every run builds and tests the native target, then packages a universal Apple Silicon + Intel `LocalImageSearch-macOS.zip` as a 30-day workflow artifact.
- A tag matching `v*` also creates a permanent GitHub Release and attaches the ZIP and SHA-256 checksum.
- Create a release with `git tag v1.0.0 && git push origin v1.0.0` after the main build is green.

## Developer ID signing and notarization

Without Apple credentials, CI produces an ad-hoc-signed app. It is usable, but downloaded copies may require right-clicking and choosing **Open** on first launch.

For a normal Gatekeeper-trusted download, add these GitHub Actions repository secrets:

- `APPLE_CERTIFICATE_BASE64`: Developer ID Application `.p12` certificate, base64 encoded.
- `APPLE_CERTIFICATE_PASSWORD`: password used when exporting that `.p12`.
- `APPLE_SIGNING_IDENTITY`: full identity, such as `Developer ID Application: Example Company (TEAMID)`.
- `APPLE_ID`: Apple ID used for notarization.
- `APPLE_TEAM_ID`: ten-character Apple Developer team ID.
- `APPLE_APP_PASSWORD`: app-specific password for the Apple ID.

Create the certificate value on macOS with:

```bash
base64 -i DeveloperIDApplication.p12 | pbcopy
```

When all signing and notarization values are present, CI imports the certificate into a temporary keychain, signs with Hardened Runtime and the app entitlements, submits the ZIP to Apple's notary service, staples the ticket, and recreates the downloadable archive. Secrets are not available to pull-request builds from forks.

## Local packaging

```bash
APP_VERSION=1.0.0 BUILD_NUMBER=1 scripts/bundle_app.sh
scripts/package_release.sh
```
