import Foundation

public actor JobScheduler {
    private let jobRepository: IndexJobRepository

    public init(jobRepository: IndexJobRepository) {
        self.jobRepository = jobRepository
    }

    @discardableResult
    public func enqueueJob(_ job: IndexJob) throws -> Bool {
        try jobRepository.enqueue(job)
    }

    public func nextEligibleJob() throws -> IndexJob? {
        try jobRepository.nextEligible(now: Date())
    }

    public func markSucceeded(jobID: UUID) throws {
        try jobRepository.updateState(
            id: jobID,
            state: .succeeded,
            finishedAt: Date()
        )
    }

    @discardableResult
    public func markFailed(jobID: UUID, error: AppError, attemptCount: Int) throws -> IndexJob.JobState {
        if error.retryClassification == .retryableWithBackoff,
           let delay = RetryPolicy.nextAttemptDelay(attemptCount: attemptCount) {
            let nextAttempt = Date().addingTimeInterval(delay)
            try jobRepository.updateState(
                id: jobID,
                state: .retryWaiting,
                attemptCount: attemptCount + 1,
                nextAttemptAt: nextAttempt,
                errorCode: error.code,
                errorMessage: error.userMessage
            )
            return .retryWaiting
        } else {
            try jobRepository.updateState(
                id: jobID,
                state: .failed,
                attemptCount: attemptCount + 1,
                errorCode: error.code,
                errorMessage: error.userMessage,
                finishedAt: Date()
            )
            return .failed
        }
    }

    public func resetInterruptedJobs() throws {
        try jobRepository.resetRunningJobsToQueued()
    }

    public func getFailedJobs() throws -> [IndexJob] {
        try jobRepository.getFailedJobs()
    }

    public func activeJobCount() throws -> Int {
        try jobRepository.countActiveJobs()
    }
}
