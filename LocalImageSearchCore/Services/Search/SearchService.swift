import Foundation

public struct SearchFilter: Sendable, Equatable {
    public var folderID: UUID?
    public var category: String?
    public var availability: ImageAsset.Availability?

    public init(
        folderID: UUID? = nil,
        category: String? = nil,
        availability: ImageAsset.Availability? = .present
    ) {
        self.folderID = folderID
        self.category = category
        self.availability = availability
    }
}

public protocol SearchServicing: Sendable {
    func search(query: String, filter: SearchFilter, limit: Int) async throws -> [SearchResult]
    func browse(filter: SearchFilter, limit: Int) async throws -> [SearchResult]
    func getRecent(limit: Int) async throws -> [SearchResult]
    func categorySummaries(limit: Int) throws -> [CategorySummary]
}

public final class SearchService: SearchServicing, Sendable {
    private let vectorIndex: VectorIndexing
    private let embeddingService: EmbeddingService
    private let searchRepository: SearchRepository
    private let assetRepository: ImageAssetRepository
    private let folderRepository: WatchedFolderRepository
    private let database: AppDatabase

    public init(
        vectorIndex: VectorIndexing,
        embeddingService: EmbeddingService,
        searchRepository: SearchRepository,
        assetRepository: ImageAssetRepository,
        folderRepository: WatchedFolderRepository,
        database: AppDatabase
    ) {
        self.vectorIndex = vectorIndex
        self.embeddingService = embeddingService
        self.searchRepository = searchRepository
        self.assetRepository = assetRepository
        self.folderRepository = folderRepository
        self.database = database
    }

    public func search(query: String, filter: SearchFilter = SearchFilter(), limit: Int = 100) async throws -> [SearchResult] {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return []
        }

        // 1. Embed query
        let queryVectors = try await embeddingService.embed([cleanQuery])
        guard let queryVector = queryVectors.first else {
            return []
        }

        // 2. Vector search (top 200)
        let vectorMatches = try await vectorIndex.nearest(to: queryVector, limit: 200)

        // 3. FTS search (top 200)
        let ftsMatches = try searchRepository.searchFTS(query: cleanQuery, limit: 200)

        // 4. Candidate IDs
        let allIDs = Array(Set(vectorMatches.map { $0.analysisID } + ftsMatches.map { $0.analysisID }))
        let details = try searchRepository.getAssetDetails(for: allIDs)

        // 5. Hybrid Rank Fusion
        let ranked = HybridRanker.fuse(
            semanticMatches: vectorMatches,
            lexicalMatches: ftsMatches,
            query: cleanQuery,
            candidateDetails: details
        )

        // 6. Map to SearchResult with filters applied
        let folders = try folderRepository.getAll()
        let folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })

        var results: [SearchResult] = []
        for candidate in ranked {
            guard let (asset, content, analysis) = details[candidate.analysisID] else {
                continue
            }

            // Apply filters
            if let targetFolder = filter.folderID, asset.folderID != targetFolder {
                continue
            }
            if let targetAvail = filter.availability, asset.availability != targetAvail {
                continue
            }
            if let targetCat = filter.category?.lowercased(), !analysis.categories.map({ $0.lowercased() }).contains(targetCat) {
                continue
            }

            guard let folder = folderMap[asset.folderID] else { continue }
            let rootURL = URL(fileURLWithPath: folder.lastResolvedPath)
            let fileURL = rootURL.appendingPathComponent(asset.relativePath)

            results.append(SearchResult(
                asset: asset,
                content: content,
                analysis: analysis,
                resolvedURL: fileURL,
                score: candidate.rrfScore,
                semanticScore: candidate.semanticScore,
                lexicalScore: candidate.lexicalScore
            ))

            if results.count >= limit {
                break
            }
        }

        return results
    }

    public func categorySummaries(limit: Int = 30) throws -> [CategorySummary] {
        try searchRepository.categorySummaries(limit: limit)
    }

    public func browse(filter: SearchFilter = SearchFilter(), limit: Int = 100) async throws -> [SearchResult] {
        let analysisIDs = try searchRepository.browseAnalysisIDs(category: filter.category, limit: max(limit * 4, 400))
        let details = try searchRepository.getAssetDetails(for: analysisIDs)
        let folders = try folderRepository.getAll()
        let folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })

        var results: [SearchResult] = []
        for analysisID in analysisIDs {
            guard let (asset, content, analysis) = details[analysisID],
                  filter.folderID == nil || asset.folderID == filter.folderID,
                  filter.availability == nil || asset.availability == filter.availability,
                  let folder = folderMap[asset.folderID] else { continue }
            let fileURL = URL(fileURLWithPath: folder.lastResolvedPath).appendingPathComponent(asset.relativePath)
            results.append(SearchResult(asset: asset, content: content, analysis: analysis, resolvedURL: fileURL, score: 1))
            if results.count >= limit { break }
        }
        return results
    }

    public func getRecent(limit: Int = 100) async throws -> [SearchResult] {
        let assets = try assetRepository.getRecent(limit: limit)
        let folders = try folderRepository.getAll()
        let folderMap = Dictionary(uniqueKeysWithValues: folders.map { ($0.id, $0) })

        var results: [SearchResult] = []
        for asset in assets {
            guard let folder = folderMap[asset.folderID] else { continue }
            let rootURL = URL(fileURLWithPath: folder.lastResolvedPath)
            let fileURL = rootURL.appendingPathComponent(asset.relativePath)

            results.append(SearchResult(
                asset: asset,
                content: nil,
                analysis: nil,
                resolvedURL: fileURL,
                score: 1.0
            ))
        }
        return results
    }
}
