import Foundation
import GRDB

public struct IndexJobRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "index_job"

    public var id: String
    public var assetId: Int64?
    public var contentId: Int64?
    public var kind: String
    public var state: String
    public var attemptCount: Int
    public var nextAttemptAt: Date?
    public var priority: Int
    public var configurationFingerprint: String?
    public var errorCode: String?
    public var errorMessage: String?
    public var createdAt: Date
    public var startedAt: Date?
    public var finishedAt: Date?

    public enum CodingKeys: String, CodingKey {
        case id
        case assetId = "asset_id"
        case contentId = "content_id"
        case kind
        case state
        case attemptCount = "attempt_count"
        case nextAttemptAt = "next_attempt_at"
        case priority
        case configurationFingerprint = "configuration_fingerprint"
        case errorCode = "error_code"
        case errorMessage = "error_message"
        case createdAt = "created_at"
        case startedAt = "started_at"
        case finishedAt = "finished_at"
    }

    public enum Columns: String, ColumnExpression {
        case id, assetId = "asset_id", contentId = "content_id", kind, state
        case attemptCount = "attempt_count", nextAttemptAt = "next_attempt_at"
        case priority, configurationFingerprint = "configuration_fingerprint"
        case errorCode = "error_code", errorMessage = "error_message"
        case createdAt = "created_at", startedAt = "started_at", finishedAt = "finished_at"
    }

    public init(from domain: IndexJob) {
        self.id = domain.id.uuidString
        self.assetId = domain.assetID
        self.contentId = domain.contentID
        self.kind = domain.kind.rawValue
        self.state = domain.state.rawValue
        self.attemptCount = domain.attemptCount
        self.nextAttemptAt = domain.nextAttemptAt
        self.priority = domain.priority
        self.configurationFingerprint = domain.configurationFingerprint
        self.errorCode = domain.errorCode
        self.errorMessage = domain.errorMessage
        self.createdAt = domain.createdAt
        self.startedAt = domain.startedAt
        self.finishedAt = domain.finishedAt
    }

    public func toDomain() -> IndexJob? {
        guard let uuid = UUID(uuidString: id),
              let k = IndexJob.JobKind(rawValue: kind),
              let s = IndexJob.JobState(rawValue: state) else {
            return nil
        }
        return IndexJob(
            id: uuid,
            assetID: assetId,
            contentID: contentId,
            kind: k,
            state: s,
            attemptCount: attemptCount,
            nextAttemptAt: nextAttemptAt,
            priority: priority,
            configurationFingerprint: configurationFingerprint,
            errorCode: errorCode,
            errorMessage: errorMessage,
            createdAt: createdAt,
            startedAt: startedAt,
            finishedAt: finishedAt
        )
    }
}
