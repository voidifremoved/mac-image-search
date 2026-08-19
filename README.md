# Local Image Search for macOS

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

Build and run the app or execute tests:

```bash
./scripts/verify.sh
```
