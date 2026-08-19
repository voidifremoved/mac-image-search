import Foundation

public final class FolderAccessStore: Sendable {
    private let repository: WatchedFolderRepository
    private let accessManager: SecurityScopedAccess

    public init(repository: WatchedFolderRepository, accessManager: SecurityScopedAccess = SecurityScopedAccess()) {
        self.repository = repository
        self.accessManager = accessManager
    }

    public func addFolder(url: URL, recursive: Bool = true) throws -> WatchedFolder {
        let existingFolders = try repository.getAll()

        // Validate no duplicate or nested roots
        let canonicalNewPath = url.standardizedFileURL.path
        for existing in existingFolders {
            let existingPath = URL(fileURLWithPath: existing.lastResolvedPath).standardizedFileURL.path
            if canonicalNewPath == existingPath {
                throw AppError(
                    subsystem: .folder,
                    code: "duplicate_folder",
                    userMessage: "This folder is already added.",
                    recoverySuggestion: "Select a different folder.",
                    retryClassification: .nonRetryable
                )
            }
            if existing.recursive && canonicalNewPath.hasPrefix(existingPath + "/") {
                throw AppError(
                    subsystem: .folder,
                    code: "nested_folder",
                    userMessage: "This folder is already inside an existing watched folder (\(existing.displayName)).",
                    recoverySuggestion: "The parent folder already indexes subfolders recursively.",
                    retryClassification: .nonRetryable
                )
            }
            if recursive && existingPath.hasPrefix(canonicalNewPath + "/") {
                throw AppError(
                    subsystem: .folder,
                    code: "enclosing_folder",
                    userMessage: "This folder encloses an existing watched folder (\(existing.displayName)).",
                    recoverySuggestion: "Remove the child folder first before adding the parent.",
                    retryClassification: .nonRetryable
                )
            }
        }

        // Create security-scoped bookmark
        let bookmarkData: Data
        do {
            #if os(macOS)
            bookmarkData = try url.bookmarkData(
                options: [.withSecurityScope],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            #else
            bookmarkData = url.path.data(using: .utf8) ?? Data()
            #endif
        } catch {
            // Fallback for environments where security-scope is not available (e.g. non-sandboxed unit tests)
            bookmarkData = url.path.data(using: .utf8) ?? Data()
        }

        let folder = WatchedFolder(
            displayName: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent,
            bookmarkData: bookmarkData,
            lastResolvedPath: canonicalNewPath,
            isEnabled: true,
            recursive: recursive,
            accessState: .available
        )

        try repository.save(folder)
        _ = accessManager.acquireLease(for: folder.id, url: url)
        return folder
    }

    public func resolveFolder(_ folder: WatchedFolder) throws -> (url: URL, isStale: Bool) {
        var isStale = false

        #if os(macOS)
        if let resolvedURL = try? URL(
            resolvingBookmarkData: folder.bookmarkData,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) {
            if isStale {
                // Refresh bookmark
                if let newBookmark = try? resolvedURL.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil) {
                    var updated = folder
                    updated.bookmarkData = newBookmark
                    updated.lastResolvedPath = resolvedURL.path
                    updated.accessState = .available
                    try? repository.save(updated)
                }
            }
            return (resolvedURL, isStale)
        }
        #endif

        // Fallback to last resolved path if bookmark resolution fails
        let fallbackURL = URL(fileURLWithPath: folder.lastResolvedPath)
        if FileManager.default.fileExists(atPath: fallbackURL.path) {
            return (fallbackURL, false)
        } else {
            try? repository.updateAccessState(id: folder.id, state: .volumeOffline, error: "Path does not exist")
            throw AppError.folderVolumeOffline(path: folder.lastResolvedPath)
        }
    }

    public func removeFolder(id: UUID) throws {
        accessManager.releaseLease(for: id)
        try repository.delete(id: id)
    }

    public func getWatchedFolders() throws -> [WatchedFolder] {
        try repository.getAll()
    }

    public func getResolvedRoots() throws -> [ResolvedFolder] {
        let enabled = try repository.getEnabled()
        var roots: [ResolvedFolder] = []

        for folder in enabled {
            do {
                let (url, _) = try resolveFolder(folder)
                _ = accessManager.acquireLease(for: folder.id, url: url)
                roots.append(ResolvedFolder(folderID: folder.id, url: url, recursive: folder.recursive))
            } catch {
                AppLogger.folderAccess.error("Failed to resolve folder \(folder.displayName): \(error.localizedDescription)")
            }
        }
        return roots
    }
}
