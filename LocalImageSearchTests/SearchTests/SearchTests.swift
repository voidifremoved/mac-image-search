import Testing
import Foundation
@testable import LocalImageSearchCore

@Suite("Embeddings & Hybrid Search Tests")
struct SearchTests {
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
}
