import Foundation
import GRDB

public struct ImageContentRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func getOrCreate(sha256: Data, byteCount: Int64) throws -> ImageContent {
        try database.write { db in
            if let existing = try ImageContentRecord.filter(ImageContentRecord.Columns.sha256 == sha256).fetchOne(db) {
                return existing.toDomain()
            }
            var record = ImageContentRecord(from: ImageContent(sha256: sha256, byteCount: byteCount))
            try record.insert(db)
            record.id = db.lastInsertedRowID
            return record.toDomain()
        }
    }

    public func get(id: Int64) throws -> ImageContent? {
        try database.read { db in
            try ImageContentRecord.fetchOne(db, key: id)?.toDomain()
        }
    }

    public func get(sha256: Data) throws -> ImageContent? {
        try database.read { db in
            try ImageContentRecord.filter(ImageContentRecord.Columns.sha256 == sha256).fetchOne(db)?.toDomain()
        }
    }
}
