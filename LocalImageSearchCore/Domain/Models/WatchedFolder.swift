import Foundation

public struct WatchedFolder: Identifiable, Sendable, Codable, Equatable, Hashable {
    public enum AccessState: String, Sendable, Codable {
        case available
        case staleBookmark
        case permissionDenied
        case volumeOffline
    }

    public let id: UUID
    public var displayName: String
    public var bookmarkData: Data
    public var lastResolvedPath: String
    public var isEnabled: Bool
    public var recursive: Bool
    public var addedAt: Date
    public var lastScanStartedAt: Date?
    public var lastScanCompletedAt: Date?
    public var lastEventID: UInt64?
    public var accessState: AccessState
    public var lastError: String?

    public init(
        id: UUID = UUID(),
        displayName: String,
        bookmarkData: Data,
        lastResolvedPath: String,
        isEnabled: Bool = true,
        recursive: Bool = true,
        addedAt: Date = Date(),
        lastScanStartedAt: Date? = nil,
        lastScanCompletedAt: Date? = nil,
        lastEventID: UInt64? = nil,
        accessState: AccessState = .available,
        lastError: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.bookmarkData = bookmarkData
        self.lastResolvedPath = lastResolvedPath
        self.isEnabled = isEnabled
        self.recursive = recursive
        self.addedAt = addedAt
        self.lastScanStartedAt = lastScanStartedAt
        self.lastScanCompletedAt = lastScanCompletedAt
        self.lastEventID = lastEventID
        self.accessState = accessState
        self.lastError = lastError
    }
}
