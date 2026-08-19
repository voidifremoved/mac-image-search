import Foundation

public struct SearchResult: Identifiable, Sendable, Equatable, Hashable {
    public var id: Int64 { asset.id ?? 0 }
    public let asset: ImageAsset
    public let content: ImageContent?
    public let analysis: ImageAnalysis?
    public let resolvedURL: URL
    public let score: Float
    public let semanticScore: Float
    public let lexicalScore: Float

    public init(
        asset: ImageAsset,
        content: ImageContent? = nil,
        analysis: ImageAnalysis? = nil,
        resolvedURL: URL,
        score: Float,
        semanticScore: Float = 0,
        lexicalScore: Float = 0
    ) {
        self.asset = asset
        self.content = content
        self.analysis = analysis
        self.resolvedURL = resolvedURL
        self.score = score
        self.semanticScore = semanticScore
        self.lexicalScore = lexicalScore
    }
}
