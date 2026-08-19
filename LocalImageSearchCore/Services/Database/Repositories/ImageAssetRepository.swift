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
