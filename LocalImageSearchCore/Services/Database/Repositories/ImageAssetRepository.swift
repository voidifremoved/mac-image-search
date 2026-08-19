import Foundation
import GRDB

public struct ImageAssetRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func upsert(_ asset: ImageAsset) throws -> ImageAsset {
        try database.write { db in
            var record = ImageAssetRecord(from: asset)
            if let existing = try ImageAssetRecord
                .filter(ImageAssetRecord.Columns.folderId == asset.folderID.uuidString &&
                        ImageAssetRecord.Columns.normalizedRelativePath == asset.normalizedRelativePath)
                .fetchOne(db) {
                record.id = existing.id
                let fileIsUnchanged = existing.fileSize == record.fileSize &&
                    existing.modifiedAt == record.modifiedAt &&
                    existing.fileResourceId == record.fileResourceId
                if fileIsUnchanged {
                    record.contentId = existing.contentId
                }
                try record.update(db)
            } else {
                try record.insert(db)
                record.id = db.lastInsertedRowID
            }
            guard let domain = record.toDomain() else {
                throw AppError(subsystem: .database, code: "conversion_error", userMessage: "Failed to map asset record to domain")
            }
            return domain
        }
    }

    public func upsertBatch(_ assets: [ImageAsset]) throws {
        try database.write { db in
            for asset in assets {
                var record = ImageAssetRecord(from: asset)
                if let existing = try ImageAssetRecord
                    .filter(ImageAssetRecord.Columns.folderId == asset.folderID.uuidString &&
                            ImageAssetRecord.Columns.normalizedRelativePath == asset.normalizedRelativePath)
                    .fetchOne(db) {
                    record.id = existing.id
                    let fileIsUnchanged = existing.fileSize == record.fileSize &&
                        existing.modifiedAt == record.modifiedAt &&
                        existing.fileResourceId == record.fileResourceId
                    if fileIsUnchanged {
                        record.contentId = existing.contentId
                    }
                    try record.update(db)
                } else {
                    try record.insert(db)
                }
            }
        }
    }

    public func get(id: Int64) throws -> ImageAsset? {
        try database.read { db in
            try ImageAssetRecord.fetchOne(db, key: id)?.toDomain()
        }
    }

    public func get(folderID: UUID, normalizedRelativePath: String) throws -> ImageAsset? {
        try database.read { db in
            try ImageAssetRecord
                .filter(ImageAssetRecord.Columns.folderId == folderID.uuidString &&
                        ImageAssetRecord.Columns.normalizedRelativePath == normalizedRelativePath)
                .fetchOne(db)?.toDomain()
        }
    }

    public func getAssets(folderID: UUID) throws -> [ImageAsset] {
        try database.read { db in
            try ImageAssetRecord
                .filter(ImageAssetRecord.Columns.folderId == folderID.uuidString)
                .fetchAll(db)
                .compactMap { $0.toDomain() }
        }
    }

    public func markMissingUnseen(folderID: UUID, currentScanID: UUID) throws -> Int {
        try database.write { db in
            try db.execute(
                sql: "UPDATE image_asset SET availability = ? WHERE folder_id = ? AND last_seen_scan_id != ? AND availability = ?",
                arguments: [
                    ImageAsset.Availability.missing.rawValue,
                    folderID.uuidString,
                    currentScanID.uuidString,
                    ImageAsset.Availability.present.rawValue
                ]
            )
            return db.changesCount
        }
    }

    public func updateContentID(assetID: Int64, contentID: Int64) throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE image_asset SET content_id = ? WHERE id = ?",
                arguments: [contentID, assetID]
            )
        }
    }

    public func updateAvailability(assetID: Int64, availability: ImageAsset.Availability, error: String? = nil) throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE image_asset SET availability = ?, last_error = ? WHERE id = ?",
                arguments: [availability.rawValue, error, assetID]
            )
        }
    }

    /// Returns true only when an asset has unfinished work. Existing vision analysis is
    /// intentionally provider/version agnostic: rescanning must never spend money again
    /// unless the source file changed or the user explicitly requests reanalysis.
    public func needsIndexing(assetID: Int64, embeddingFingerprint: EmbeddingFingerprint?) throws -> Bool {
        try database.read { db in
            var arguments: StatementArguments = [assetID]
            let embeddingJoin: String
            if let fingerprint = embeddingFingerprint {
                embeddingJoin = """
                LEFT JOIN embedding stored_embedding
                  ON stored_embedding.analysis_id = analysis.id
                 AND stored_embedding.engine_kind = ?
                 AND stored_embedding.model = ?
                 AND stored_embedding.revision = ?
                """
                arguments += [fingerprint.engineKind, fingerprint.model, fingerprint.revision]
            } else {
                embeddingJoin = "LEFT JOIN embedding stored_embedding ON 0"
            }

            let sql = """
            SELECT asset.content_id AS content_id,
                   analysis.id AS analysis_id,
                   stored_embedding.id AS embedding_id
            FROM image_asset asset
            LEFT JOIN image_analysis analysis
              ON analysis.content_id = asset.content_id
             AND analysis.is_current = 1
            \(embeddingJoin)
            WHERE asset.id = ?
            LIMIT 1
            """

            // The asset ID is the final placeholder because embedding parameters occur
            // first in SQL text when that join is present.
            if let fingerprint = embeddingFingerprint {
                arguments = [fingerprint.engineKind, fingerprint.model, fingerprint.revision, assetID]
            }
            guard let row = try Row.fetchOne(db, sql: sql, arguments: arguments) else { return true }
            let contentID: Int64? = row["content_id"]
            let analysisID: Int64? = row["analysis_id"]
            let embeddingID: Int64? = row["embedding_id"]
            if contentID == nil || analysisID == nil { return true }
            return embeddingFingerprint != nil && embeddingID == nil
        }
    }

    public func countAll() throws -> Int {
        try database.read { db in
            try ImageAssetRecord.fetchCount(db)
        }
    }

    public func getRecent(limit: Int = 100) throws -> [ImageAsset] {
        try database.read { db in
            try ImageAssetRecord
                .filter(ImageAssetRecord.Columns.availability == ImageAsset.Availability.present.rawValue)
                .order(ImageAssetRecord.Columns.discoveredAt.desc)
                .limit(limit)
                .fetchAll(db)
                .compactMap { $0.toDomain() }
        }
    }
}
