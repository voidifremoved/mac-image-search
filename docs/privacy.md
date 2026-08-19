# Privacy Policy & Data Handling — Local Image Search

## What Stays 100% On Your Mac
- Your source image files are **never modified, moved, or uploaded**.
- Your image catalog, descriptions, tags, and search vectors reside exclusively on your local Mac in SQLite (`~/Library/Application Support/LocalImageSearch/catalog.sqlite`).
- Queries typed in the search bar are embedded and evaluated entirely on your Mac.
- API keys are stored exclusively in the macOS Keychain (`com.localimagesearch.secrets`) and never logged, exported, or synced.

## What Is Sent to Configured AI Providers
- When new or changed images are analyzed, a privacy-preserving downsampled preview (maximum 1600 pixels) is rendered.
- All EXIF metadata, GPS locations, camera serial numbers, original filenames, and full filesystem paths are **completely stripped** prior to transmission.
- Previews are transmitted directly via HTTPS to your configured OpenAI-compatible endpoint (such as OpenRouter).
