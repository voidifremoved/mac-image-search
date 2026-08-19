import Foundation
import GRDB

public struct ImageContentRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "image_content"

    public var id: Int64?
    public var sha256: Data
    public var byteCount: Int64
    public var createdAt: Date

    public enum CodingKeys: String, CodingKey {
        case id
        case sha256
        case byteCount = "byte_count"
        case createdAt = "created_at"
    }

    public enum Columns: String, ColumnExpression {
        case id, sha256, byteCount = "byte_count", createdAt = "created_at"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    public init(from domain: ImageContent) {
        self.id = domain.id
        self.sha256 = domain.sha256
        self.byteCount = domain.byteCount
        self.createdAt = domain.createdAt
    }

    public func toDomain() -> ImageContent {
        ImageContent(
            id: id,
            sha256: sha256,
            byteCount: byteCount,
            createdAt: createdAt
        )
    }
}
