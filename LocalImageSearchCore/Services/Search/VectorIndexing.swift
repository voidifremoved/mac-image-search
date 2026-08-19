import Foundation

public protocol VectorIndexing: Sendable {
    func rebuild(from records: [VectorRecord]) async throws
    func upsert(_ records: [VectorRecord]) async throws
    func remove(ids: [Int64]) async
    func nearest(to vector: [Float], limit: Int) async throws -> [VectorMatch]
}
