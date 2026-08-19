import Testing
import Foundation
import GRDB
@testable import LocalImageSearchCore

private struct UnavailableEmbeddingService: EmbeddingService {
    var fingerprint: EmbeddingFingerprint {
        get async throws { throw AppError.embeddingUnavailable(detail: "Unavailable in test") }
    }

    func embed(_ texts: [String]) async throws -> [[Float]] {
        throw AppError.embeddingUnavailable(detail: "Unavailable in test")
    }
}

@Suite("Database Foundation Tests")
struct DatabaseTests {
    @Test("In-memory database creates schema and passes integrity check")
    func testDatabaseCreationAndIntegrity() throws {
        let db = try AppDatabase.inMemory()
        try db.read { database in
            let integrity = try String.fetchOne(database, sql: "PRAGMA integrity_check")
            #expect(integrity == "ok")
        }
    }

    @Test("Watched folder CRUD and cascade delete")
    func testWatchedFolderCRUD() throws {
        let db = try AppDatabase.inMemory()
        let folderRepo = WatchedFolderRepository(database: db)
        let assetRepo = ImageAssetRepository(database: db)

        let folder = WatchedFolder(
            displayName: "Test Pictures",
            bookmarkData: Data([1, 2, 3, 4]),
            lastResolvedPath: "/Users/test/Pictures"
        )
        try folderRepo.save(folder)

        let fetched = try folderRepo.get(id: folder.id)
        #expect(fetched != nil)
        #expect(fetched?.displayName == "Test Pictures")
        #expect(fetched?.accessState == .available)

        let asset = ImageAsset(
            folderID: folder.id,
            relativePath: "photo.jpg",
            normalizedRelativePath: "photo.jpg",
            fileSize: 1024,
            modifiedAt: Date(),
            lastSeenScanID: UUID()
        )
        _ = try assetRepo.upsert(asset)
        #expect(try assetRepo.countAll() == 1)

        try folderRepo.delete(id: folder.id)
        #expect(try folderRepo.get(id: folder.id) == nil)
        #expect(try assetRepo.countAll() == 0)
    }

    @Test("Duplicate image content linking and analysis FTS indexing")
    func testContentAndAnalysisFTS() throws {
        let db = try AppDatabase.inMemory()
        let contentRepo = ImageContentRepository(database: db)
        let analysisRepo = ImageAnalysisRepository(database: db)
        let searchRepo = SearchRepository(database: db)

        let hashData = Data(repeating: 0x42, count: 32)
        let content = try contentRepo.getOrCreate(sha256: hashData, byteCount: 2048)
        #expect(content.id != nil)

        let duplicate = try contentRepo.getOrCreate(sha256: hashData, byteCount: 2048)
        #expect(duplicate.id == content.id)

        let analysis = ImageAnalysis(
            contentID: content.id!,
            providerKind: "openrouter",
            baseURLFingerprint: "test-fp",
            model: "google/gemini-flash",
            description: "A beautiful golden sunset over a calm ocean with distant sailboats",
            shortTitle: "Ocean Sunset with Sailboats",
            categories: ["nature", "ocean"],
            objects: ["sailboat", "sun", "water"],
            scene: "coastal sunset",
            dominantColors: ["gold", "orange", "blue"],
            visibleText: nil,
            searchableText: "ocean sunset sailboats gold"
        )
        let saved = try analysisRepo.save(analysis)

        #expect(saved.id != nil)

        let matches = try searchRepo.searchFTS(query: "sailboats sunset")
        #expect(!matches.isEmpty)
        #expect(matches.first?.analysisID == saved.id)
    }

    @Test("Analysis storage preserves long full-text transcription")
    func testFullTextTranscriptionRoundTrip() throws {
        let db = try AppDatabase.inMemory()
        let contentRepo = ImageContentRepository(database: db)
        let analysisRepo = ImageAnalysisRepository(database: db)
        let content = try contentRepo.getOrCreate(
            sha256: Data(repeating: 0x71, count: 32),
            byteCount: 4096
        )
        let transcription = String(repeating: "Account 0192 | Line item | £123.45\n", count: 300)
        let analysis = ImageAnalysis(
            contentID: content.id!,
            providerKind: "test",
            baseURLFingerprint: "test",
            model: "vision",
            description: "A detailed financial statement.",
            shortTitle: "Financial Statement",
            categories: ["documents"],
            objects: ["table"],
            visibleText: transcription,
            searchableText: "summary: financial statement\nfull text transcription:\n\(transcription)"
        )
        _ = try analysisRepo.save(analysis)

        let fetched = try analysisRepo.getCurrent(contentID: content.id!)
        #expect(fetched?.description == "A detailed financial statement.")
        #expect(fetched?.visibleText == transcription)
        #expect(fetched!.visibleText!.count > 10_000)
        let textMatches = try SearchRepository(database: db).searchFTS(query: "Account 0192")
        #expect(!textMatches.isEmpty)
    }

    @Test("Categories are counted and can be used for drilldown")
    func testCategorySummariesAndBrowse() async throws {
        let db = try AppDatabase.inMemory()
        let folderRepo = WatchedFolderRepository(database: db)
        let assetRepo = ImageAssetRepository(database: db)
        let contentRepo = ImageContentRepository(database: db)
        let analysisRepo = ImageAnalysisRepository(database: db)
        let searchRepo = SearchRepository(database: db)

        let folder = WatchedFolder(displayName: "Pictures", bookmarkData: Data(), lastResolvedPath: "/tmp/pictures")
        try folderRepo.save(folder)

        let content = try contentRepo.getOrCreate(sha256: Data(repeating: 0x33, count: 32), byteCount: 100)
        var asset = ImageAsset(
            folderID: folder.id,
            relativePath: "forest.jpg",
            normalizedRelativePath: "forest.jpg",
            contentID: content.id,
            fileSize: 100,
            modifiedAt: Date(),
            lastSeenScanID: UUID()
        )
        asset = try assetRepo.upsert(asset)
        #expect(asset.id != nil)

        let analysis = ImageAnalysis(
            contentID: content.id!,
            providerKind: "test",
            baseURLFingerprint: "test",
            model: "vision",
            description: "A trail through a green forest",
            shortTitle: "Forest Trail",
            categories: ["Nature", "Landscape"],
            objects: ["trees", "trail"],
            visibleText: "FOREST PERMIT\nReference: AbC-123",
            searchableText: "forest trail nature landscape FOREST PERMIT Reference AbC-123"
        )
        let saved = try analysisRepo.save(analysis)

        // Existing analysis is retained even when provider/prompt settings change.
        #expect(try assetRepo.needsIndexing(assetID: asset.id!, embeddingFingerprint: nil) == false)
        let fingerprint = EmbeddingFingerprint(engineKind: "test", model: "embed", revision: "1", dimension: 2)
        #expect(try assetRepo.needsIndexing(assetID: asset.id!, embeddingFingerprint: fingerprint))
        _ = try EmbeddingRepository(database: db).save(StoredEmbedding(
            analysisID: saved.id!,
            engineKind: fingerprint.engineKind,
            model: fingerprint.model,
            revision: fingerprint.revision,
            dimension: fingerprint.dimension,
            vector: Data(count: fingerprint.dimension * MemoryLayout<Float>.size),
            sourceTextSHA256: Data()
        ))
        #expect(try assetRepo.needsIndexing(assetID: asset.id!, embeddingFingerprint: fingerprint) == false)

        let summaries = try searchRepo.categorySummaries()
        #expect(summaries.contains(CategorySummary(name: "Nature", imageCount: 1)))
        #expect(summaries.contains(CategorySummary(name: "Landscape", imageCount: 1)))
        #expect(try searchRepo.browseAnalysisIDs(category: "nature") == [saved.id!])
        #expect(try searchRepo.browseAnalysisIDs(category: "portrait").isEmpty)
        #expect(try searchRepo.searchFilenames(query: "forest").first?.analysisID == saved.id)
        #expect(try searchRepo.searchExactVisibleText(query: "forest permit").first == saved.id)
        #expect(try searchRepo.searchExactVisibleText(query: "permit reference").isEmpty)

        let service = SearchService(
            vectorIndex: ExactVectorIndex(),
            embeddingService: UnavailableEmbeddingService(),
            searchRepository: searchRepo,
            assetRepository: assetRepo,
            folderRepository: folderRepo,
            database: db
        )
        let results = try await service.browse(filter: SearchFilter(category: "Nature"), limit: 20)
        #expect(results.count == 1)
        #expect(results.first?.analysis?.shortTitle == "Forest Trail")
        #expect(results.first?.resolvedURL.lastPathComponent == "forest.jpg")

        let prefixResults = try await service.search(query: "fore", limit: 20)
        #expect(prefixResults.first?.analysis?.shortTitle == "Forest Trail")
        let filenameResults = try await service.search(query: "jpg", limit: 20)
        #expect(filenameResults.first?.resolvedURL.lastPathComponent == "forest.jpg")
        let exactTextResults = try await service.search(
            query: "reference: abc-123",
            filter: SearchFilter(exactImageTextOnly: true),
            limit: 20
        )
        #expect(exactTextResults.first?.analysis?.shortTitle == "Forest Trail")
        let nonExactResults = try await service.search(
            query: "forest reference",
            filter: SearchFilter(exactImageTextOnly: true),
            limit: 20
        )
        #expect(nonExactResults.isEmpty)
    }

    @Test("Index job idempotency and eligible worker fetch")
    func testIndexJobTransitions() throws {
        let db = try AppDatabase.inMemory()
        let contentRepo = ImageContentRepository(database: db)
        let jobRepo = IndexJobRepository(database: db)

        let content = try contentRepo.getOrCreate(sha256: Data(repeating: 0x99, count: 32), byteCount: 1024)
        #expect(content.id != nil)

        let job1 = IndexJob(contentID: content.id, kind: .analyze, priority: 5)
        try jobRepo.enqueue(job1)

        let jobDuplicate = IndexJob(contentID: content.id, kind: .analyze, priority: 1)
        try jobRepo.enqueue(jobDuplicate)

        let eligible = try jobRepo.nextEligible()
        #expect(eligible != nil)
        #expect(eligible?.id == job1.id)
        #expect(eligible?.state == .running)

        let next = try jobRepo.nextEligible()
        #expect(next == nil)
    }

    @Test("Index jobs are processed chronologically")
    func testIndexJobChronologicalOrder() throws {
        let db = try AppDatabase.inMemory()
        let contentRepo = ImageContentRepository(database: db)
        let jobRepo = IndexJobRepository(database: db)
        let olderContent = try contentRepo.getOrCreate(sha256: Data(repeating: 0x10, count: 32), byteCount: 10)
        let newerContent = try contentRepo.getOrCreate(sha256: Data(repeating: 0x20, count: 32), byteCount: 20)
        let now = Date()
        let newerJob = IndexJob(contentID: newerContent.id, kind: .analyze, priority: 1, createdAt: now)
        let olderJob = IndexJob(contentID: olderContent.id, kind: .analyze, priority: 1, createdAt: now.addingTimeInterval(-3_600))

        try jobRepo.enqueue(newerJob)
        try jobRepo.enqueue(olderJob)

        #expect(try jobRepo.nextEligible()?.id == olderJob.id)
    }
}
