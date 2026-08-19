import Foundation
import GRDB

public struct EmbeddingRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func save(_ embedding: StoredEmbedding) throws -> StoredEmbedding {
        try database.write { db in
            var record = EmbeddingRecord(from: embedding)
            if let existing = try EmbeddingRecord
                .filter(EmbeddingRecord.Columns.analysisId == embedding.analysisID &&
                        EmbeddingRecord.Columns.engineKind == embedding.engineKind &&
                        EmbeddingRecord.Columns.model == embedding.model &&
                        EmbeddingRecord.Columns.revision == embedding.revision)
                .fetchOne(db) {
                record.id = existing.id
                try record.update(db)
            } else {
                try record.insert(db)
                record.id = db.lastInsertedRowID
            }
            return record.toDomain()
        }
    }

    public func get(analysisID: Int64, engineKind: String, model: String, revision: String) throws -> StoredEmbedding? {
        try database.read { db in
            try EmbeddingRecord
                .filter(EmbeddingRecord.Columns.analysisId == analysisID &&
                        EmbeddingRecord.Columns.engineKind == engineKind &&
                        EmbeddingRecord.Columns.model == model &&
                        EmbeddingRecord.Columns.revision == revision)
                .fetchOne(db)?.toDomain()
        }
    }

    public func getAll(engineKind: String, model: String, revision: String) throws -> [StoredEmbedding] {
        try database.read { db in
            try EmbeddingRecord
                .filter(EmbeddingRecord.Columns.engineKind == engineKind &&
                        EmbeddingRecord.Columns.model == model &&
                        EmbeddingRecord.Columns.revision == revision)
                .fetchAll(db)
                .map { $0.toDomain() }
        }
    }

    public func count(engineKind: String, model: String, revision: String) throws -> Int {
        try database.read { db in
            try EmbeddingRecord
                .filter(EmbeddingRecord.Columns.engineKind == engineKind &&
                        EmbeddingRecord.Columns.model == model &&
                        EmbeddingRecord.Columns.revision == revision)
                .fetchCount(db)
        }
    }
}
