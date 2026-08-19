import Foundation
import GRDB

public struct IndexJobRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    @discardableResult
    public func enqueue(_ job: IndexJob) throws -> Bool {
        try database.write { db in
            var request = IndexJobRecord.filter(IndexJobRecord.Columns.kind == job.kind.rawValue)
            let activeStates = [
                IndexJob.JobState.queued.rawValue,
                IndexJob.JobState.running.rawValue,
                IndexJob.JobState.retryWaiting.rawValue
            ]
            request = request.filter(activeStates.contains(IndexJobRecord.Columns.state))
            if let assetID = job.assetID {
                request = request.filter(IndexJobRecord.Columns.assetId == assetID)
            }
            if let contentID = job.contentID {
                request = request.filter(IndexJobRecord.Columns.contentId == contentID)
            }

            if try request.fetchOne(db) != nil {
                return false
            }
            let record = IndexJobRecord(from: job)
            try record.insert(db)
            return true
        }
    }

    public func nextEligible(now: Date = Date()) throws -> IndexJob? {
        try database.write { db in
            let queued = IndexJobRecord.Columns.state == IndexJob.JobState.queued.rawValue
            let retryWaiting = IndexJobRecord.Columns.state == IndexJob.JobState.retryWaiting.rawValue
            let retryEligible = IndexJobRecord.Columns.nextAttemptAt == nil || IndexJobRecord.Columns.nextAttemptAt <= now
            
            let row = try IndexJobRecord
                .filter(queued || (retryWaiting && retryEligible))
                .order(IndexJobRecord.Columns.priority.desc, IndexJobRecord.Columns.createdAt.asc)
                .fetchOne(db)

            guard var job = row?.toDomain() else { return nil }
            job.state = .running
            job.startedAt = now
            let updatedRecord = IndexJobRecord(from: job)
            try updatedRecord.update(db)
            return job
        }
    }

    public func updateState(
        id: UUID,
        state: IndexJob.JobState,
        attemptCount: Int? = nil,
        nextAttemptAt: Date? = nil,
        errorCode: String? = nil,
        errorMessage: String? = nil,
        finishedAt: Date? = nil
    ) throws {
        try database.write { db in
            guard var record = try IndexJobRecord.fetchOne(db, key: id.uuidString) else { return }
            record.state = state.rawValue
            if let attemptCount { record.attemptCount = attemptCount }
            record.nextAttemptAt = nextAttemptAt
            record.errorCode = errorCode
            record.errorMessage = errorMessage
            record.finishedAt = finishedAt
            try record.update(db)
        }
    }

    public func resetRunningJobsToQueued() throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE index_job SET state = ? WHERE state = ?",
                arguments: [IndexJob.JobState.queued.rawValue, IndexJob.JobState.running.rawValue]
            )
        }
    }

    public func getFailedJobs(limit: Int = 100) throws -> [IndexJob] {
        try database.read { db in
            try IndexJobRecord
                .filter(IndexJobRecord.Columns.state == IndexJob.JobState.failed.rawValue)
                .order(IndexJobRecord.Columns.createdAt.desc)
                .limit(limit)
                .fetchAll(db)
                .compactMap { $0.toDomain() }
        }
    }

    public func countActiveJobs() throws -> Int {
        try database.read { db in
            let activeStates = [
                IndexJob.JobState.queued.rawValue,
                IndexJob.JobState.running.rawValue,
                IndexJob.JobState.retryWaiting.rawValue
            ]
            return try IndexJobRecord
                .filter(activeStates.contains(IndexJobRecord.Columns.state))
                .fetchCount(db)
        }
    }
}
