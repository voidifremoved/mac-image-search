import Foundation

public struct ImageContent: Identifiable, Sendable, Codable, Equatable, Hashable {
    public var id: Int64?
    public var sha256: Data
    public var byteCount: Int64
    public var createdAt: Date

    public init(
        id: Int64? = nil,
        sha256: Data,
        byteCount: Int64,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.sha256 = sha256
        self.byteCount = byteCount
        self.createdAt = createdAt
    }

    public var hexSHA256: String {
        sha256.map { String(format: "%02x", $0) }.joined()
    }
}
