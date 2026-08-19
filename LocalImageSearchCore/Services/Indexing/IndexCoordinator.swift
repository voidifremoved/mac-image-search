import Foundation

public actor IndexCoordinator {
    public enum IndexerState: String, Sendable {
        case idle
        case scanning
        case indexing
        case paused
    }

    private let database: AppDatabase
    private let folderAccessStore: FolderAccessStore
    private let fileEnumerator: FileEnumerator
    private let assetRepository: ImageAssetRepository
    private let pipeline: IndexPipeline
    private let scheduler: JobScheduler
    private let vectorIndex: VectorIndexing
    private let embeddingRepository: EmbeddingRepository
    private let embeddingService: EmbeddingService

    private(set) public var state: IndexerState = .idle
    private(set) public var totalDiscoveredCount: Int = 0
    private(set) public var completedCount: Int = 0
    private(set) public var failedCount: Int = 0
    private(set) public var totalJobCount: Int = 0
    private var isPaused: Bool = false
    private var hasStarted: Bool = false
    private var currentFileName: String?
    private var activeWorkerTask: Task<Void, Never>?

    public init(
        database: AppDatabase,
        folderAccessStore: FolderAccessStore,
        fileEnumerator: FileEnumerator = FileEnumerator(),
        assetRepository: ImageAssetRepository,
        pipeline: IndexPipeline,
        scheduler: JobScheduler,
        vectorIndex: VectorIndexing,
        embeddingRepository: EmbeddingRepository,
        embeddingService: EmbeddingService
    ) {
        self.database = database
        self.folderAccessStore = folderAccessStore
        self.fileEnumerator = fileEnumerator
        self.assetRepository = assetRepository
        self.pipeline = pipeline
        self.scheduler = scheduler
        self.vectorIndex = vectorIndex
        self.embeddingRepository = embeddingRepository
        self.embeddingService = embeddingService
    }

    public func start() async throws {
        guard !hasStarted else { return }
        hasStarted = true
        try await scheduler.resetInterruptedJobs()
        try await preloadVectorIndex()
        try await scanAllFolders()
        startWorker()
    }

    public func preloadVectorIndex() async throws {
        let fingerprint = try await embeddingService.fingerprint
        let stored = try embeddingRepository.getAll(
            engineKind: fingerprint.engineKind,
            model: fingerprint.model,
            revision: fingerprint.revision
        )

        var records: [VectorRecord] = []
        for emb in stored {
            if let floatArray = emb.floatArray() {
                records.append(VectorRecord(analysisID: emb.analysisID, vector: floatArray))
            }
        }
        try await vectorIndex.rebuild(from: records)
    }

    public func scanAllFolders() async throws {
        state = .scanning
        completedCount = 0
        failedCount = 0
        totalJobCount = 0
        currentFileName = nil
        let roots = try folderAccessStore.getResolvedRoots()
        let embeddingFingerprint = try? await embeddingService.fingerprint

        for root in roots {
            let scanID = UUID()
            let discovered = try fileEnumerator.enumerate(root: root)

            var assetsToUpsert: [ImageAsset] = []
            for item in discovered {
                let asset = ImageAsset(
                    folderID: root.folderID,
                    relativePath: item.relativePath,
                    normalizedRelativePath: item.normalizedRelativePath,
                    fileResourceID: item.metadata.fileResourceID,
                    fileSize: item.metadata.fileSize,
                    modifiedAt: item.metadata.modifiedAt,
                    createdAt: item.metadata.createdAt,
                    pixelWidth: item.pixelWidth,
                    pixelHeight: item.pixelHeight,
                    uti: item.uti,
                    lastSeenScanID: scanID,
                    availability: .present
                )
                assetsToUpsert.append(asset)
            }

            try assetRepository.upsertBatch(assetsToUpsert)
            _ = try assetRepository.markMissingUnseen(folderID: root.folderID, currentScanID: scanID)

            // Process chronologically. Creation date is preferred; modification date is
            // the stable fallback for formats/filesystems without a creation timestamp.
            let chronologicalAssets = assetsToUpsert.sorted {
                let lhsDate = $0.createdAt ?? $0.modifiedAt
                let rhsDate = $1.createdAt ?? $1.modifiedAt
                if lhsDate == rhsDate { return $0.normalizedRelativePath < $1.normalizedRelativePath }
                return lhsDate < rhsDate
            }

            // Only queue genuinely new or incomplete assets. Interrupted active jobs are
            // already persisted and enqueueJob de-duplicates them.
            for asset in chronologicalAssets {
                if let savedAsset = try assetRepository.get(folderID: root.folderID, normalizedRelativePath: asset.normalizedRelativePath),
                   let assetID = savedAsset.id,
                   try assetRepository.needsIndexing(assetID: assetID, embeddingFingerprint: embeddingFingerprint) {
                    let fileDate = savedAsset.createdAt ?? savedAsset.modifiedAt
                    let job = IndexJob(assetID: assetID, kind: .analyze, priority: 1, createdAt: fileDate)
                    if try await scheduler.enqueueJob(job) {
                        totalJobCount += 1
                    }
                }
            }
        }

        totalDiscoveredCount = try assetRepository.countAll()
        totalJobCount = max(totalJobCount, try await scheduler.activeJobCount())
        state = .idle
        startWorker()
    }

    public func pause() {
        isPaused = true
        state = .paused
    }

    public func resume() {
        isPaused = false
        state = .idle
        startWorker()
    }

    private func startWorker() {
        guard activeWorkerTask == nil else { return }

        activeWorkerTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self = self else { break }
                let paused = await self.isPaused
                if paused {
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    continue
                }

                guard let job = try? await self.scheduler.nextEligibleJob() else {
                    await self.setIdleState()
                    try? await Task.sleep(nanoseconds: 1_000_000_000)
                    continue
                }

                await self.setIndexingState()
                await self.processJob(job)
            }
        }
    }

    private func processJob(_ job: IndexJob) async {
        guard let assetID = job.assetID,
              let asset = try? assetRepository.get(id: assetID),
              let folder = try? folderAccessStore.getWatchedFolders().first(where: { $0.id == asset.folderID }) else {
            if let result = try? await scheduler.markFailed(
                jobID: job.id,
                error: AppError(subsystem: .file, code: "asset_not_found", userMessage: "Asset could not be resolved"),
                attemptCount: job.attemptCount
            ), result == .failed {
                failedCount += 1
            }
            return
        }

        currentFileName = URL(fileURLWithPath: asset.relativePath).lastPathComponent

        let rootURL = URL(fileURLWithPath: folder.lastResolvedPath)
        let fileURL = rootURL.appendingPathComponent(asset.relativePath)

        do {
            try await pipeline.processAsset(assetID: assetID, fileURL: fileURL)
            try await scheduler.markSucceeded(jobID: job.id)
            completedCount += 1
        } catch let err as AppError {
            if let result = try? await scheduler.markFailed(jobID: job.id, error: err, attemptCount: job.attemptCount),
               result == .failed {
                failedCount += 1
            }
        } catch {
            let appErr = AppError(subsystem: .system, code: "unknown_error", userMessage: error.localizedDescription)
            if let result = try? await scheduler.markFailed(jobID: job.id, error: appErr, attemptCount: job.attemptCount),
               result == .failed {
                failedCount += 1
            }
        }
        currentFileName = nil
    }

    public func progressSnapshot() -> IndexProgress {
        IndexProgress(
            state: state,
            discoveredCount: totalDiscoveredCount,
            totalJobCount: max(totalJobCount, completedCount + failedCount),
            completedCount: completedCount,
            failedCount: failedCount,
            currentFileName: currentFileName
        )
    }

    private func setIdleState() {
        if !isPaused {
            state = .idle
        }
    }

    private func setIndexingState() {
        if !isPaused {
            state = .indexing
        }
    }
}
