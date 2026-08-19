import Testing
import Foundation
@testable import LocalImageSearchCore

@Suite("Diagnostics & Export Tests")
struct DiagnosticsTests {
    @Test("Diagnostics report exports sanitized telemetry")
    func testDiagnosticsExport() throws {
        let db = try AppDatabase.inMemory()
        let folderRepo = WatchedFolderRepository(database: db)
        let assetRepo = ImageAssetRepository(database: db)
        let jobRepo = IndexJobRepository(database: db)
        let providerConfig = AIProviderConfiguration()

        let folder = WatchedFolder(
            displayName: "Test",
            bookmarkData: Data(),
            lastResolvedPath: "/Users/test/Pictures"
        )
        try folderRepo.save(folder)

        let report = try DiagnosticsExporter.generateReport(
            database: db,
            folderRepo: folderRepo,
            assetRepo: assetRepo,
            jobRepo: jobRepo,
            providerConfig: providerConfig
        )

        #expect(report.watchedFolderCount == 1)
        #expect(report.totalAssetsCount == 0)
        #expect(report.databaseSchemaVersion == 1)

        let json = try DiagnosticsExporter.exportJSON(report: report)
        #expect(json.contains("watchedFolderCount"))
        #expect(!json.contains("secret"))
        #expect(!json.contains("key"))
    }
}
