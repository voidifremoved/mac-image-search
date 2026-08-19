import Foundation

public struct IndexProgress: Sendable, Equatable {
    public let state: IndexCoordinator.IndexerState
    public let discoveredCount: Int
    public let totalJobCount: Int
    public let completedCount: Int
    public let failedCount: Int
    public let currentFileName: String?

    public init(
        state: IndexCoordinator.IndexerState,
        discoveredCount: Int,
        totalJobCount: Int,
        completedCount: Int,
        failedCount: Int,
        currentFileName: String?
    ) {
        self.state = state
        self.discoveredCount = discoveredCount
        self.totalJobCount = totalJobCount
        self.completedCount = completedCount
        self.failedCount = failedCount
        self.currentFileName = currentFileName
    }

    public var processedCount: Int { completedCount + failedCount }
    public var remainingCount: Int { max(0, totalJobCount - processedCount) }
    public var fractionCompleted: Double {
        guard totalJobCount > 0 else { return state == .idle ? 1 : 0 }
        return min(1, Double(processedCount) / Double(totalJobCount))
    }

    public var isActive: Bool {
        state == .scanning || state == .indexing || state == .paused || remainingCount > 0
    }

    public static let idle = IndexProgress(
        state: .idle,
        discoveredCount: 0,
        totalJobCount: 0,
        completedCount: 0,
        failedCount: 0,
        currentFileName: nil
    )
}
