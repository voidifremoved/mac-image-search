# Local Image Search for macOS

[![Build and Release macOS App](https://github.com/voidifremoved/mac-image-search/actions/workflows/build-and-release.yml/badge.svg)](https://github.com/voidifremoved/mac-image-search/actions/workflows/build-and-release.yml)

A native macOS application that watches user-selected folders, analyzes images with vision-capable AI (OpenRouter or OpenAI-compatible endpoints), stores extracted metadata and semantic vectors locally on your Mac, and lets you find images using natural language queries.

## Key Features

- **Semantic & Natural Language Search**: Find images by describing scenes, objects, colors, or visible text.
- **100% Local Catalog**: All metadata, embeddings, and full-text indexes live locally in SQLite.
- **Privacy-First**: Transmits only downsampled previews with all EXIF/GPS/path metadata stripped.
- **Fast Local Retrieval**: Exact cosine vector similarity powered by Apple Accelerate vDSP and Reciprocal Rank Fusion with SQLite FTS5.
- **Folder Watching**: Automatically detects new, modified, moved, or deleted images via macOS FSEvents.
- **Duplicate Detection**: Content-addressed SHA-256 deduplication ensures duplicate files share single vision analyses.
- **Keychain Secret Storage**: API keys are securely stored in the macOS Keychain.

## Requirements

- macOS 14.0 (Sonoma) or later
- Swift 6.0+

## Getting Started

### Download

Download the latest universal `LocalImageSearch-macOS.zip` from [GitHub Releases](https://github.com/voidifremoved/mac-image-search/releases), unzip it, and move `LocalImageSearch.app` into Applications. The same download supports Apple Silicon and Intel Macs running macOS 14 or later.

Release builds are automatically produced from tags matching `v*`, for example `v1.0.0`. If a release is not Developer ID signed and notarized, macOS may require right-clicking the app and choosing **Open** the first time. Maintainers can configure the Apple signing secrets described in [the release guide](docs/release.md) to produce normal Gatekeeper-trusted downloads.

### Build locally

Build and run the app or execute tests:

```bash
./scripts/verify.sh
```
