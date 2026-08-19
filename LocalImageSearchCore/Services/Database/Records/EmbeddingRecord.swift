import Foundation
import GRDB

public struct EmbeddingRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "embedding"

    public var id: Int64?
    public var analysisId: Int64
    public var engineKind: String
    public var model: String
    public var revision: String
    public var dimension: Int
    public var vector: Data
    public var sourceTextSha256: Data
    public var createdAt: Date

    public enum CodingKeys: String, CodingKey {
        case id
        case analysisId = "analysis_id"
        case engineKind = "engine_kind"
        case model
        case revision
        case dimension
        case vector
        case sourceTextSha256 = "source_text_sha256"
        case createdAt = "created_at"
    }

    public enum Columns: String, ColumnExpression {
        case id, analysisId = "analysis_id", engineKind = "engine_kind", model
        case revision, dimension, vector, sourceTextSha256 = "source_text_sha256"
        case createdAt = "created_at"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    public init(from domain: StoredEmbedding) {
        self.id = domain.id
        self.analysisId = domain.analysisID
        self.engineKind = domain.engineKind
        self.model = domain.model
        self.revision = domain.revision
        self.dimension = domain.dimension
        self.vector = domain.vector
        self.sourceTextSha256 = domain.sourceTextSHA256
        self.createdAt = domain.createdAt
    }

    public func toDomain() -> StoredEmbedding {
        StoredEmbedding(
            id: id,
            analysisID: analysisId,
            engineKind: engineKind,
            model: model,
            revision: revision,
            dimension: dimension,
            vector: vector,
            sourceTextSHA256: sourceTextSha256,
            createdAt: createdAt
        )
    }
}
