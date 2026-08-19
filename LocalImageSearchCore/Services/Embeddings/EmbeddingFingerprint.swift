import Foundation

public struct EmbeddingFingerprint: Sendable, Codable, Equatable, Hashable, CustomStringConvertible {
    public let engineKind: String
    public let model: String
    public let revision: String
    public let dimension: Int
    public let textTransformVersion: String

    public init(
        engineKind: String,
        model: String,
        revision: String,
        dimension: Int,
        textTransformVersion: String = "searchable-text-v1"
    ) {
        self.engineKind = engineKind
        self.model = model
        self.revision = revision
        self.dimension = dimension
        self.textTransformVersion = textTransformVersion
    }

    public var identifier: String {
        "\(engineKind):\(model):rev-\(revision):dim-\(dimension):\(textTransformVersion)"
    }

    public var description: String {
        identifier
    }
}
