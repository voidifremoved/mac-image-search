import Foundation

public final class IndexPipeline: Sendable {
    private let database: AppDatabase
    private let contentRepository: ImageContentRepository
    private let assetRepository: ImageAssetRepository
    private let analysisRepository: ImageAnalysisRepository
    private let embeddingRepository: EmbeddingRepository
    private let visionAnalyzer: VisionAnalyzer
    private let embeddingService: EmbeddingService
    private let vectorIndex: VectorIndexing
    private let providerConfig: AIProviderConfiguration

    public init(
        database: AppDatabase,
        contentRepository: ImageContentRepository,
        assetRepository: ImageAssetRepository,
        analysisRepository: ImageAnalysisRepository,
        embeddingRepository: EmbeddingRepository,
        visionAnalyzer: VisionAnalyzer,
        embeddingService: EmbeddingService,
        vectorIndex: VectorIndexing,
        providerConfig: AIProviderConfiguration
    ) {
        self.database = database
        self.contentRepository = contentRepository
        self.assetRepository = assetRepository
        self.analysisRepository = analysisRepository
        self.embeddingRepository = embeddingRepository
        self.visionAnalyzer = visionAnalyzer
        self.embeddingService = embeddingService
        self.vectorIndex = vectorIndex
        self.providerConfig = providerConfig
    }

    public func processAsset(assetID: Int64, fileURL: URL) async throws {
        // 1. Stable file check
        let isStable = (try? await FileIdentityReader.isFileStable(at: fileURL, delaySeconds: 0.2)) ?? true
        guard isStable else {
            throw AppError.fileUnstable(path: fileURL.path)
        }

        // 2. Stream SHA-256
        let sha256 = try FileIdentityReader.computeStreamingSHA256(at: fileURL)
        let metadata = try FileIdentityReader.readMetadata(at: fileURL)

        // 3. Link Content
        let content = try contentRepository.getOrCreate(sha256: sha256, byteCount: metadata.fileSize)
        guard let contentID = content.id else { return }
        try assetRepository.updateContentID(assetID: assetID, contentID: contentID)

        // 4. Check if current analysis already exists
        let currentAnalysis: ImageAnalysis
        if let existing = try analysisRepository.getCurrent(
            contentID: contentID,
            baseURLFingerprint: providerConfig.configurationFingerprint,
            model: providerConfig.model,
            promptVersion: AnalysisPrompt.currentPromptVersion,
            schemaVersion: AnalysisPrompt.currentSchemaVersion
        ) {
            currentAnalysis = existing
        } else {
            // Build downsampled preview
            let previewInput = try AnalysisPreviewBuilder.buildPreview(from: fileURL)

            // Analyze with Vision AI
            let analysisResponse = try await visionAnalyzer.analyze(previewInput)

            // Persist analysis
            let newAnalysis = ImageAnalysis(
                contentID: contentID,
                providerKind: providerConfig.preset.rawValue,
                baseURLFingerprint: providerConfig.configurationFingerprint,
                model: providerConfig.model,
                promptVersion: AnalysisPrompt.currentPromptVersion,
                schemaVersion: AnalysisPrompt.currentSchemaVersion,
                description: analysisResponse.description,
                shortTitle: analysisResponse.shortTitle,
                categories: analysisResponse.categories,
                objects: analysisResponse.objects,
                scene: analysisResponse.scene,
                dominantColors: analysisResponse.dominantColors,
                visibleText: analysisResponse.visibleText,
                peopleCount: analysisResponse.peopleCount,
                timeOfDay: analysisResponse.timeOfDay,
                searchableText: analysisResponse.buildSearchableText()
            )
            currentAnalysis = try analysisRepository.save(newAnalysis)
        }

        // 5. Generate and store embedding
        guard let analysisID = currentAnalysis.id else { return }
        let fingerprint = try await embeddingService.fingerprint

        if (try embeddingRepository.get(
            analysisID: analysisID,
            engineKind: fingerprint.engineKind,
            model: fingerprint.model,
            revision: fingerprint.revision
        )) == nil {
            let vectors = try await embeddingService.embed([currentAnalysis.searchableText])
            if let vector = vectors.first {
                let vectorData = vector.withUnsafeBufferPointer { Data(buffer: $0) }
                let textSHA = currentAnalysis.searchableText.data(using: .utf8) ?? Data()

                let storedEmb = StoredEmbedding(
                    analysisID: analysisID,
                    engineKind: fingerprint.engineKind,
                    model: fingerprint.model,
                    revision: fingerprint.revision,
                    dimension: fingerprint.dimension,
                    vector: vectorData,
                    sourceTextSHA256: textSHA
                )
                _ = try embeddingRepository.save(storedEmb)

                // Update in-memory vector index
                try await vectorIndex.upsert([VectorRecord(analysisID: analysisID, vector: vector)])
            }
        }
    }
}
