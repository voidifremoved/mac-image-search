import Foundation

public struct IndexJob: Identifiable, Sendable, Codable, Equatable, Hashable {
    public enum JobKind: String, Sendable, Codable {
        case hash
        case analyze
        case embed
        case thumbnail
        case reconcile
    }

    public enum JobState: String, Sendable, Codable {
        case queued
        case running
        case retryWaiting
        case succeeded
        case failed
        case cancelled
    }

    public let id: UUID
    public var assetID: Int64?
    public var contentID: Int64?
    public var kind: JobKind
    public var state: JobState
    public var attemptCount: Int
    public var nextAttemptAt: Date?
    public var priority: Int
    public var configurationFingerprint: String?
    public var errorCode: String?
    public var errorMessage: String?
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?

    public init(
        id: UUID = UUID(),
        assetID: Int64? = nil,
        contentID: Int64? = nil,
        kind: JobKind,
        state: JobState = .queued,
        attemptCount: Int = 0,
        nextAttemptAt: Date? = nil,
        priority: Int = 0,
        configurationFingerprint: String? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        createdAt: Date = Date(),
        startedAt: Date? = nil,
        finishedAt: Date? = nil
    ) {
        self.id = id
        self.assetID = assetID
        self.contentID = contentID
        self.kind = kind
        self.state = state
        self.attemptCount = attemptCount
        self.nextAttemptAt = nextAttemptAt
        self.priority = priority
        self.configurationFingerprint = configurationFingerprint
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.createdAt = createdAt
        self.startedAt = startedAt
        self.finishedAt = finishedAt
    }
}
