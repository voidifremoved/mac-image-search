import Testing
import Foundation
@testable import LocalImageSearchCore

@Suite("Folder Access and Security Scope Tests")
struct FolderAccessTests {
    @Test("Adding folders validates nested and duplicate paths")
    func testNestedAndDuplicateValidation() throws {
        let db = try AppDatabase.inMemory()
        let folderRepo = WatchedFolderRepository(database: db)
        let store = FolderAccessStore(repository: folderRepo)

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let subDir = tempDir.appendingPathComponent("Subfolder")
        try FileManager.default.createDirectory(at: subDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        // Add parent folder
        let parent = try store.addFolder(url: tempDir, recursive: true)
        #expect(parent.displayName == tempDir.lastPathComponent)

        // Attempt duplicate add
        #expect(throws: AppError.self) {
            try store.addFolder(url: tempDir, recursive: true)
        }

        // Attempt nested add
        #expect(throws: AppError.self) {
            try store.addFolder(url: subDir, recursive: true)
        }
    }

    @Test("Security scoped lease acquisition and release")
    func testSecurityScopedLeases() throws {
        let access = SecurityScopedAccess()
        let testID = UUID()
        let tempDir = FileManager.default.temporaryDirectory

        let acquired = access.acquireLease(for: testID, url: tempDir)
        #expect(acquired)

        access.releaseLease(for: testID)
    }
}
