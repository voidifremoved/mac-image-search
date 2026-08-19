import Foundation

public protocol EmbeddingService: Sendable {
    var fingerprint: EmbeddingFingerprint { get async throws }
    func embed(_ texts: [String]) async throws -> [[Float]]
}
