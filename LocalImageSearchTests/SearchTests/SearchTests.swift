import Testing
import Foundation
@testable import LocalImageSearchCore

@Suite("Embeddings & Hybrid Search Tests")
struct SearchTests {
    @Test("Background result refresh preserves the selected inspector item")
    func testBackgroundRefreshPreservesSelection() {
        func result(id: Int64, title: String) -> SearchResult {
            let asset = ImageAsset(
                id: id,
                folderID: UUID(),
                relativePath: "\(id).jpg",
                normalizedRelativePath: "\(id).jpg",
                fileSize: 10,
                modifiedAt: Date(),
                lastSeenScanID: UUID()
            )
            let analysis = ImageAnalysis(
                id: id,
                contentID: id,
                providerKind: "test",
                baseURLFingerprint: "test",
                model: "test",
                description: title,
                shortTitle: title,
                categories: [],
                objects: [],
                searchableText: title
            )
            return SearchResult(
                asset: asset,
                analysis: analysis,
                resolvedURL: URL(fileURLWithPath: "/tmp/\(id).jpg"),
                score: 1
            )
        }

        let selected = result(id: 7, title: "Original metadata")
        let refreshed = result(id: 7, title: "Refreshed metadata")
        let preserved = ResultSelectionPolicy.selectionAfterRefresh(
            current: selected,
            refreshedResults: [refreshed, result(id: 8, title: "New background result")],
            preservesSelection: true
        )

        #expect(preserved?.id == selected.id)
        #expect(preserved?.analysis?.shortTitle == "Refreshed metadata")
        #expect(ResultSelectionPolicy.selectionAfterRefresh(
            current: selected,
            refreshedResults: [result(id: 8, title: "Other")],
            preservesSelection: true
        ) == selected)
        #expect(ResultSelectionPolicy.selectionAfterRefresh(
            current: selected,
            refreshedResults: [refreshed],
            preservesSelection: false
        ) == nil)
    }

    @Test("Exact vector index finds closest normalized vector")
    func testExactVectorIndex() async throws {
        let index = ExactVectorIndex()

        let rec1 = VectorRecord(analysisID: 1, vector: [1.0, 0.0, 0.0])
        let rec2 = VectorRecord(analysisID: 2, vector: [0.0, 1.0, 0.0])
        let rec3 = VectorRecord(analysisID: 3, vector: [0.707, 0.707, 0.0])

        try await index.rebuild(from: [rec1, rec2, rec3])
        #expect(await index.count() == 3)

        // Query close to rec1
        let matches = try await index.nearest(to: [0.99, 0.01, 0.0], limit: 2)
        #expect(matches.count == 2)
        #expect(matches.first?.analysisID == 1)
    }

    @Test("Hybrid ranker fuses semantic and lexical ranks with filename boost")
    func testHybridRankerFusion() throws {
        let semanticMatches = [
            VectorMatch(analysisID: 10, score: 0.95),
            VectorMatch(analysisID: 20, score: 0.80)
        ]
        let lexicalMatches = [
            SearchRepository.FTSMatch(analysisID: 20, rank: -5.0),
            SearchRepository.FTSMatch(analysisID: 30, rank: -3.0)
        ]

        let dummyAsset = ImageAsset(
            folderID: UUID(),
            relativePath: "red_car_snow.jpg",
            normalizedRelativePath: "red_car_snow.jpg",
            fileSize: 100,
            modifiedAt: Date(),
            lastSeenScanID: UUID()
        )
        let dummyContent = ImageContent(sha256: Data(), byteCount: 100)
        let dummyAnalysis = ImageAnalysis(
            contentID: 1,
            providerKind: "test",
            baseURLFingerprint: "fp",
            model: "model",
            description: "desc",
            shortTitle: "title",
            categories: [],
            objects: [],
            searchableText: "text"
        )

        let details: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] = [
            10: (asset: dummyAsset, content: dummyContent, analysis: dummyAnalysis),
            20: (asset: dummyAsset, content: dummyContent, analysis: dummyAnalysis),
            30: (asset: dummyAsset, content: dummyContent, analysis: dummyAnalysis)
        ]

        let candidates = HybridRanker.fuse(
            semanticMatches: semanticMatches,
            lexicalMatches: lexicalMatches,
            query: "red car",
            candidateDetails: details
        )

        #expect(!candidates.isEmpty)
        #expect(candidates.contains(where: { $0.analysisID == 10 }))
        #expect(candidates.contains(where: { $0.analysisID == 20 }))
    }

    @Test("Hybrid ranker removes irrelevant vector neighbors")
    func testHybridRankerFiltersWeakNeighbors() {
        let folderID = UUID()
        func details(id: Int64, title: String, description: String) -> (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis) {
            let asset = ImageAsset(
                folderID: folderID,
                relativePath: "\(id).jpg",
                normalizedRelativePath: "\(id).jpg",
                fileSize: 10,
                modifiedAt: Date(),
                lastSeenScanID: UUID()
            )
            let content = ImageContent(id: id, sha256: Data([UInt8(id)]), byteCount: 10)
            let analysis = ImageAnalysis(
                id: id,
                contentID: id,
                providerKind: "test",
                baseURLFingerprint: "test",
                model: "test",
                description: description,
                shortTitle: title,
                categories: [],
                objects: [],
                searchableText: "\(title) \(description)"
            )
            return (asset, content, analysis)
        }

        let allDetails: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] = [
            1: details(id: 1, title: "Rocky Beach Sunset", description: "Orange sun over waves"),
            2: details(id: 2, title: "Tax Spreadsheet", description: "Rows of accounting figures"),
            3: details(id: 3, title: "Office Chair", description: "Black chair in a room")
        ]
        let candidates = HybridRanker.fuse(
            semanticMatches: [
                VectorMatch(analysisID: 1, score: 0.82),
                VectorMatch(analysisID: 2, score: 0.30),
                VectorMatch(analysisID: 3, score: 0.05)
            ],
            lexicalMatches: [],
            query: "sunset beach",
            candidateDetails: allDetails
        )

        #expect(candidates.map(\.analysisID) == [Int64(1)])
    }

    @Test("Hybrid ranker stops before borderline semantic neighbors")
    func testHybridRankerStopsAtConfidenceFloor() {
        let folderID = UUID()
        func details(id: Int64, title: String, category: String? = nil) -> (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis) {
            let asset = ImageAsset(
                folderID: folderID,
                relativePath: "\(id).jpg",
                normalizedRelativePath: "\(id).jpg",
                fileSize: 10,
                modifiedAt: Date(),
                lastSeenScanID: UUID()
            )
            let content = ImageContent(id: id, sha256: Data([UInt8(id)]), byteCount: 10)
            let analysis = ImageAnalysis(
                id: id,
                contentID: id,
                providerKind: "test",
                baseURLFingerprint: "test",
                model: "test",
                description: title,
                shortTitle: title,
                categories: category.map { [$0] } ?? [],
                objects: [],
                searchableText: title
            )
            return (asset, content, analysis)
        }

        let allDetails: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] = [
            1: details(id: 1, title: "Funny reaction image", category: "Meme"),
            2: details(id: 2, title: "Comedic visual joke"),
            3: details(id: 3, title: "Person opening a cardboard box"),
            4: details(id: 4, title: "Software dashboard screenshot")
        ]
        let candidates = HybridRanker.fuse(
            semanticMatches: [
                VectorMatch(analysisID: 1, score: 0.70),
                VectorMatch(analysisID: 2, score: 0.68),
                VectorMatch(analysisID: 3, score: 0.61),
                VectorMatch(analysisID: 4, score: 0.60)
            ],
            lexicalMatches: [SearchRepository.FTSMatch(analysisID: 1, rank: -4)],
            query: "funny memes",
            candidateDetails: allDetails
        )

        #expect(candidates.map(\.analysisID).contains(1))
        #expect(candidates.map(\.analysisID).contains(2))
        #expect(!candidates.map(\.analysisID).contains(3))
        #expect(!candidates.map(\.analysisID).contains(4))
    }

    @Test("Semantic-only search has no unbounded weak-result tail")
    func testSemanticOnlyResultCap() {
        let folderID = UUID()
        var details: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] = [:]
        var matches: [VectorMatch] = []
        for id in Int64(1)...Int64(30) {
            let asset = ImageAsset(
                id: id,
                folderID: folderID,
                relativePath: "\(id).jpg",
                normalizedRelativePath: "\(id).jpg",
                fileSize: 10,
                modifiedAt: Date(),
                lastSeenScanID: UUID()
            )
            let content = ImageContent(id: id, sha256: Data([UInt8(id)]), byteCount: 10)
            let analysis = ImageAnalysis(
                id: id,
                contentID: id,
                providerKind: "test",
                baseURLFingerprint: "test",
                model: "test",
                description: "Unlabelled visual content \(id)",
                shortTitle: "Image \(id)",
                categories: [],
                objects: [],
                searchableText: "Unlabelled visual content"
            )
            details[id] = (asset, content, analysis)
            matches.append(VectorMatch(analysisID: id, score: 0.90 - Float(id - 1) * 0.001))
        }

        let candidates = HybridRanker.fuse(
            semanticMatches: matches,
            lexicalMatches: [],
            query: "abstract concept",
            candidateDetails: details
        )
        #expect(candidates.count <= 16)
    }
}
