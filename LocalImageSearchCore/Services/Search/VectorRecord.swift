import Foundation

public struct VectorRecord: Sendable, Equatable {
    public let analysisID: Int64
    public let vector: [Float]

    public init(analysisID: Int64, vector: [Float]) {
        self.analysisID = analysisID
        self.vector = vector
    }
}

public struct VectorMatch: Sendable, Equatable {
    public let analysisID: Int64
    public let score: Float

    public init(analysisID: Int64, score: Float) {
        self.analysisID = analysisID
        self.score = score
    }
}
