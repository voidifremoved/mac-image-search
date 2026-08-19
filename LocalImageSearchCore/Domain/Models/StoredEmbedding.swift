import Foundation

public struct StoredEmbedding: Identifiable, Sendable, Codable, Equatable, Hashable {
    public var id: Int64?
    public var analysisID: Int64
    public var engineKind: String
    public var model: String
    public var revision: String
    public var dimension: Int
    public var vector: Data
    public var sourceTextSHA256: Data
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        analysisID: Int64,
        engineKind: String,
        model: String,
        revision: String,
        dimension: Int,
        vector: Data,
        sourceTextSHA256: Data,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.analysisID = analysisID
        self.engineKind = engineKind
        self.model = model
        self.revision = revision
        self.dimension = dimension
        self.vector = vector
        self.sourceTextSHA256 = sourceTextSHA256
        self.createdAt = createdAt
    }

    public func floatArray() -> [Float]? {
        guard vector.count == dimension * MemoryLayout<Float>.size else { return nil }
        return vector.withUnsafeBytes { rawBuffer in
            guard let baseAddress = rawBuffer.baseAddress else { return [] }
            let typed = baseAddress.assumingMemoryBound(to: Float.self)
            return Array(UnsafeBufferPointer(start: typed, count: dimension))
        }
    }
}
