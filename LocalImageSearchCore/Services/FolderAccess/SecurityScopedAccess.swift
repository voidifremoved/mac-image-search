import Foundation

public final class SecurityScopedAccess: @unchecked Sendable {
    private let lock = NSLock()
    private var activeLeases: [UUID: URL] = [:]

    public init() {}

    public static func withAccess<T>(to url: URL, operation: (URL) throws -> T) throws -> T {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try operation(url)
    }

    public static func withAsyncAccess<T: Sendable>(to url: URL, operation: @Sendable (URL) async throws -> T) async throws -> T {
        let isSecurityScoped = url.startAccessingSecurityScopedResource()
        defer {
            if isSecurityScoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await operation(url)
    }

    public func acquireLease(for folderID: UUID, url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let existing = activeLeases[folderID] {
            if existing.path == url.path {
                return true
            }
            existing.stopAccessingSecurityScopedResource()
            activeLeases.removeValue(forKey: folderID)
        }

        let started = url.startAccessingSecurityScopedResource()
        if started {
            activeLeases[folderID] = url
            return true
        }
        // Even if not security-scoped (e.g. in test environments), store for tracking
        activeLeases[folderID] = url
        return true
    }

    public func releaseLease(for folderID: UUID) {
        lock.lock()
        defer { lock.unlock() }

        if let url = activeLeases.removeValue(forKey: folderID) {
            url.stopAccessingSecurityScopedResource()
        }
    }

    public func releaseAllLeases() {
        lock.lock()
        defer { lock.unlock() }

        for (_, url) in activeLeases {
            url.stopAccessingSecurityScopedResource()
        }
        activeLeases.removeAll()
    }

    deinit {
        releaseAllLeases()
    }
}
