import Foundation
import GRDB

public struct SearchRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public struct FTSMatch: Sendable, Equatable {
        public let analysisID: Int64
        public let rank: Double

        public init(analysisID: Int64, rank: Double) {
            self.analysisID = analysisID
            self.rank = rank
        }
    }

    public func categorySummaries(limit: Int = 30) throws -> [CategorySummary] {
        try database.read { db in
            let sql = """
            SELECT lower(trim(category.value)) AS category, COUNT(DISTINCT asset.id) AS image_count
            FROM image_analysis analysis
            JOIN image_content content ON content.id = analysis.content_id
            JOIN image_asset asset ON asset.content_id = content.id
            JOIN json_each(analysis.categories_json) category
            WHERE analysis.is_current = 1
              AND asset.availability = 'present'
              AND category.type = 'text'
              AND trim(category.value) != ''
            GROUP BY lower(trim(category.value))
            ORDER BY image_count DESC, category ASC
            LIMIT ?
            """
            return try Row.fetchAll(db, sql: sql, arguments: [limit]).compactMap { row in
                guard let name: String = row["category"],
                      let count: Int = row["image_count"] else { return nil }
                return CategorySummary(name: name.capitalized, imageCount: count)
            }
        }
    }

    public func browseAnalysisIDs(category: String? = nil, limit: Int = 400) throws -> [Int64] {
        try database.read { db in
            var arguments: StatementArguments = []
            var categoryClause = ""
            if let category, !category.isEmpty {
                categoryClause = "AND EXISTS (SELECT 1 FROM json_each(analysis.categories_json) item WHERE lower(trim(item.value)) = lower(trim(?)))"
                arguments += [category]
            }
            arguments += [limit]
            let sql = """
            SELECT DISTINCT analysis.id
            FROM image_analysis analysis
            JOIN image_content content ON content.id = analysis.content_id
            JOIN image_asset asset ON asset.content_id = content.id
            WHERE analysis.is_current = 1
              AND asset.availability = 'present'
              \(categoryClause)
            ORDER BY analysis.created_at DESC
            LIMIT ?
            """
            return try Int64.fetchAll(db, sql: sql, arguments: arguments)
        }
    }

    public func searchFTS(query: String, limit: Int = 200) throws -> [FTSMatch] {
        let tokens = Self.searchTokens(query)
        let sanitized = tokens
            .map { token in
                token.count >= 3 ? "\"\(token)\"*" : "\"\(token)\""
            }
            .joined(separator: " OR ")

        guard !sanitized.isEmpty else { return [] }

        return try database.read { db in
            let sql = """
            SELECT analysis_id, rank
            FROM analysis_fts
            WHERE analysis_fts MATCH ?
            ORDER BY rank
            LIMIT ?
            """
            let rows = try Row.fetchAll(db, sql: sql, arguments: [sanitized, limit])
            return rows.compactMap { row in
                guard let analysisID = row["analysis_id"] as Int64?,
                      let rank = row["rank"] as Double? else {
                    return nil
                }
                return FTSMatch(analysisID: analysisID, rank: rank)
            }
        }
    }

    public func searchFilenames(query: String, limit: Int = 100) throws -> [FTSMatch] {
        let tokens = Self.searchTokens(query)
        guard !tokens.isEmpty else { return [] }

        return try database.read { db in
            let conditions = tokens.map { _ in "lower(asset.relative_path) LIKE ? ESCAPE '\\'" }
                .joined(separator: " OR ")
            let patterns = tokens.map { "%\(Self.escapeLikePattern($0.lowercased()))%" }
            let sql = """
            SELECT DISTINCT analysis.id
            FROM image_analysis analysis
            JOIN image_content content ON content.id = analysis.content_id
            JOIN image_asset asset ON asset.content_id = content.id
            WHERE analysis.is_current = 1
              AND asset.availability = 'present'
              AND (\(conditions))
            ORDER BY analysis.created_at DESC
            LIMIT ?
            """
            var arguments = StatementArguments(patterns)
            arguments += [limit]
            let ids = try Int64.fetchAll(db, sql: sql, arguments: arguments)
            return ids.enumerated().map { index, id in
                FTSMatch(analysisID: id, rank: Double(index))
            }
        }
    }

    /// Finds a contiguous phrase in the model's full image transcription. This is
    /// intentionally separate from FTS token matching and semantic retrieval.
    public func searchExactVisibleText(query: String, limit: Int = 200) throws -> [Int64] {
        let phrase = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !phrase.isEmpty else { return [] }

        return try database.read { db in
            let sql = """
            SELECT DISTINCT analysis.id
            FROM image_analysis analysis
            JOIN image_content content ON content.id = analysis.content_id
            JOIN image_asset asset ON asset.content_id = content.id
            WHERE analysis.is_current = 1
              AND asset.availability = 'present'
              AND analysis.visible_text IS NOT NULL
              AND instr(lower(analysis.visible_text), lower(?)) > 0
            ORDER BY analysis.created_at DESC
            LIMIT ?
            """
            return try Int64.fetchAll(db, sql: sql, arguments: [phrase, limit])
        }
    }

    private static func searchTokens(_ query: String) -> [String] {
        let stopWords: Set<String> = ["a", "an", "and", "are", "at", "for", "in", "is", "of", "on", "the", "to", "with"]
        return query
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .map { $0.lowercased() }
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    private static func escapeLikePattern(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    public func getAssetDetails(for analysisIDs: [Int64]) throws -> [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] {
        guard !analysisIDs.isEmpty else { return [:] }
        return try database.read { db in
            let analysisRecords = try ImageAnalysisRecord
                .filter(analysisIDs.contains(ImageAnalysisRecord.Columns.id))
                .filter(ImageAnalysisRecord.Columns.isCurrent == true)
                .fetchAll(db)
            let contentIDs = Array(Set(analysisRecords.map(\.contentId)))
            let contentRecords = try ImageContentRecord
                .filter(contentIDs.contains(ImageContentRecord.Columns.id))
                .fetchAll(db)
            let assetRecords = try ImageAssetRecord
                .filter(contentIDs.contains(ImageAssetRecord.Columns.contentId))
                .filter(ImageAssetRecord.Columns.availability == ImageAsset.Availability.present.rawValue)
                .order(ImageAssetRecord.Columns.discoveredAt.desc)
                .fetchAll(db)

            let contentsByID = Dictionary(uniqueKeysWithValues: contentRecords.compactMap { record in
                record.id.map { ($0, record.toDomain()) }
            })
            var assetsByContentID: [Int64: ImageAsset] = [:]
            for record in assetRecords {
                guard let contentID = record.contentId,
                      assetsByContentID[contentID] == nil,
                      let asset = record.toDomain() else { continue }
                assetsByContentID[contentID] = asset
            }

            var result: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)] = [:]
            for record in analysisRecords {
                guard let analysisID = record.id,
                      let content = contentsByID[record.contentId],
                      let asset = assetsByContentID[record.contentId] else { continue }
                result[analysisID] = (asset: asset, content: content, analysis: record.toDomain())
            }
            return result
        }
    }
}
