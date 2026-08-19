import Foundation

public struct DiagnosticsReport: Sendable, Codable {
    public let appVersion: String
    public let osVersion: String
    public let databaseSchemaVersion: Int
    public let watchedFolderCount: Int
    public let totalAssetsCount: Int
    public let failedJobsCount: Int
    public let providerPreset: String
    public let providerModel: String
    public let timestamp: Date

    public init(
        appVersion: String = "1.0.0",
        osVersion: String = ProcessInfo.processInfo.operatingSystemVersionString,
        databaseSchemaVersion: Int = 1,
        watchedFolderCount: Int,
        totalAssetsCount: Int,
        failedJobsCount: Int,
        providerPreset: String,
        providerModel: String,
        timestamp: Date = Date()
    ) {
        self.appVersion = appVersion
        self.osVersion = osVersion
        self.databaseSchemaVersion = databaseSchemaVersion
        self.watchedFolderCount = watchedFolderCount
        self.totalAssetsCount = totalAssetsCount
        self.failedJobsCount = failedJobsCount
        self.providerPreset = providerPreset
        self.providerModel = providerModel
        self.timestamp = timestamp
    }
}

public enum DiagnosticsExporter {
    public static func generateReport(
        database: AppDatabase,
        folderRepo: WatchedFolderRepository,
        assetRepo: ImageAssetRepository,
        jobRepo: IndexJobRepository,
        providerConfig: AIProviderConfiguration
    ) throws -> DiagnosticsReport {
        let folders = try folderRepo.getAll()
        let assetCount = try assetRepo.countAll()
        let failedJobs = try jobRepo.getFailedJobs()

        return DiagnosticsReport(
            watchedFolderCount: folders.count,
            totalAssetsCount: assetCount,
            failedJobsCount: failedJobs.count,
            providerPreset: providerConfig.preset.rawValue,
            providerModel: providerConfig.model
        )
    }

    public static func exportJSON(report: DiagnosticsReport) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
