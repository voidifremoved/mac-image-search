# Architecture Overview — Local Image Search for macOS

## 1. System Architecture

Local Image Search is a native macOS application built with Swift 6 and SwiftUI. It combines local SQLite storage, on-device Apple sentence embeddings, Accelerate/vDSP exact cosine vector indexing, FTS5 lexical indexing, and OpenAI-compatible vision AI analysis.

### Service Graph
- **Composition Root**: `AppEnvironment` manages lifecycle and dependency injection.
- **Persistence Layer**: `AppDatabase` (GRDB with WAL mode, foreign keys, and FTS5).
- **Security Scope**: `FolderAccessStore` & `SecurityScopedAccess` maintain App Sandbox read-only leases and refresh stale bookmarks.
- **Discovery**: `FileEnumerator` and `FileIdentityReader` perform incremental file scanning, stable-file validation, and CryptoKit streaming SHA-256 deduplication.
- **Vision AI**: `AnalysisPreviewBuilder` downsamples previews (max 1600px, EXIF orientation, metadata stripping) and `OpenAICompatibleVisionClient` conducts structured analysis.
- **Embeddings & Search**: `AppleSentenceEmbeddingService` (NaturalLanguage), `ExactVectorIndex` (Accelerate vDSP dot product), and `HybridRanker` (Reciprocal Rank Fusion with lexical FTS).
- **Orchestrator**: `IndexCoordinator` and `JobScheduler` prioritize and execute background indexing with pause/resume and crash recovery.
- **Live Watching**: `FolderWatcher` (FSEvents async stream with debouncing and reconciliation).

## 2. Concurrency and Data Invariants
- All UI views and view models are bound to `@MainActor`.
- Indexing coordination, vector indexing, and scheduler are implemented as actors.
- Image assets share unique content rows via SHA-256, avoiding duplicate vision API calls.
- SQLite remains the single source of truth for all metadata and vectors.
