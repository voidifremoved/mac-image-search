import Foundation
import GRDB

public struct ImageAnalysisRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func save(_ analysis: ImageAnalysis) throws -> ImageAnalysis {
        try database.write { db in
            try db.execute(
                sql: "UPDATE image_analysis SET is_current = 0 WHERE content_id = ?",
                arguments: [analysis.contentID]
            )

            var record = try ImageAnalysisRecord(from: analysis)
            try record.insert(db)
            let insertedID = db.lastInsertedRowID
            record.id = insertedID

            try db.execute(
                sql: "INSERT INTO analysis_fts(analysis_id, short_title, description, categories, objects, scene, visible_text) VALUES (?, ?, ?, ?, ?, ?, ?)",
                arguments: [
                    insertedID,
                    analysis.shortTitle,
                    analysis.description,
                    analysis.categories.joined(separator: " "),
                    analysis.objects.joined(separator: " "),
                    analysis.scene ?? "",
                    analysis.visibleText ?? ""
                ]
            )

            return record.toDomain()
        }
    }

    public func getCurrent(contentID: Int64) throws -> ImageAnalysis? {
        try database.read { db in
            try ImageAnalysisRecord
                .filter(ImageAnalysisRecord.Columns.contentId == contentID && ImageAnalysisRecord.Columns.isCurrent == true)
                .fetchOne(db)?.toDomain()
        }
    }

    public func get(id: Int64) throws -> ImageAnalysis? {
        try database.read { db in
            try ImageAnalysisRecord.fetchOne(db, key: id)?.toDomain()
        }
    }

    public func getAllCurrent() throws -> [ImageAnalysis] {
        try database.read { db in
            try ImageAnalysisRecord
                .filter(ImageAnalysisRecord.Columns.isCurrent == true)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }
}
