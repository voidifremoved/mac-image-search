import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import LocalImageSearchCore

@Suite("Indexing Pipeline & Coordinator Tests")
struct IndexingTests {
    @Test("End-to-end pipeline processes asset with mock vision and local embeddings")
    func testPipelineEndToEnd() async throws {
        let db = try AppDatabase.inMemory()
        let folderRepo = WatchedFolderRepository(database: db)
        let contentRepo = ImageContentRepository(database: db)
        let assetRepo = ImageAssetRepository(database: db)
        let analysisRepo = ImageAnalysisRepository(database: db)
        let embeddingRepo = EmbeddingRepository(database: db)

        let mockVision = MockVisionAnalyzer()
        let embeddingService = AppleSentenceEmbeddingService()
        let vectorIndex = ExactVectorIndex()
        let providerConfig = AIProviderConfiguration()

        let pipeline = IndexPipeline(
            database: db,
            contentRepository: contentRepo,
            assetRepository: assetRepo,
            analysisRepository: analysisRepo,
            embeddingRepository: embeddingRepo,
            visionAnalyzer: mockVision,
            embeddingService: embeddingService,
            vectorIndex: vectorIndex,
            providerConfig: providerConfig
        )

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create dummy PNG
        let imageURL = tempDir.appendingPathComponent("lake_sunset.png")
        let context = CGContext(
            data: nil,
            width: 40,
            height: 40,
            bitsPerComponent: 8,
            bytesPerRow: 40 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let cgImage = context.makeImage()!
        let dest = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)

        let folder = WatchedFolder(
            displayName: "Test",
            bookmarkData: Data(),
            lastResolvedPath: tempDir.path
        )
        try folderRepo.save(folder)

        let asset = ImageAsset(
            folderID: folder.id,
            relativePath: "lake_sunset.png",
            normalizedRelativePath: "lake_sunset.png",
            fileSize: 500,
            modifiedAt: Date(),
            lastSeenScanID: UUID()
        )
        let savedAsset = try assetRepo.upsert(asset)

        try await pipeline.processAsset(assetID: savedAsset.id!, fileURL: imageURL)

        #expect(mockVision.analyzeCallCount == 1)
        #expect(await vectorIndex.count() == 1)

        // Verify analysis was saved in database
        let currentAnalyses = try analysisRepo.getAllCurrent()
        #expect(currentAnalyses.count == 1)
        #expect(currentAnalyses.first?.shortTitle == "Test Mock Image")
    }

    @Test("RetryPolicy calculates jittered exponential backoff and respects max attempts")
    func testRetryPolicy() {
        let delay1 = RetryPolicy.nextAttemptDelay(attemptCount: 0)
        #expect(delay1 != nil)
        #expect(delay1! >= 1.5 && delay1! <= 2.5)

        let delay5 = RetryPolicy.nextAttemptDelay(attemptCount: 5)
        #expect(delay5 == nil) // Max attempts reached
    }
}
