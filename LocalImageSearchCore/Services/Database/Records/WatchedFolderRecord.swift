import Foundation
import GRDB

public struct WatchedFolderRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "watched_folder"

    public var id: String
    public var displayName: String
    public var bookmarkData: Data
    public var lastResolvedPath: String
    public var isEnabled: Bool
    public var recursive: Bool
    public var addedAt: Date
    public var lastScanStartedAt: Date?
    public var lastScanCompletedAt: Date?
    public var lastEventID: Int64?
    public var accessState: String
    public var lastError: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
        case bookmarkData = "bookmark_data"
        case lastResolvedPath = "last_resolved_path"
        case isEnabled = "is_enabled"
        case recursive
        case addedAt = "added_at"
        case lastScanStartedAt = "last_scan_started_at"
        case lastScanCompletedAt = "last_scan_completed_at"
        case lastEventID = "last_event_id"
        case accessState = "access_state"
        case lastError = "last_error"
    }

    public enum Columns: String, ColumnExpression {
        case id, displayName = "display_name", bookmarkData = "bookmark_data"
        case lastResolvedPath = "last_resolved_path", isEnabled = "is_enabled"
        case recursive, addedAt = "added_at", lastScanStartedAt = "last_scan_started_at"
        case lastScanCompletedAt = "last_scan_completed_at", lastEventID = "last_event_id"
        case accessState = "access_state", lastError = "last_error"
    }

    public init(from domain: WatchedFolder) {
        self.id = domain.id.uuidString
        self.displayName = domain.displayName
        self.bookmarkData = domain.bookmarkData
        self.lastResolvedPath = domain.lastResolvedPath
        self.isEnabled = domain.isEnabled
        self.recursive = domain.recursive
        self.addedAt = domain.addedAt
        self.lastScanStartedAt = domain.lastScanStartedAt
        self.lastScanCompletedAt = domain.lastScanCompletedAt
        self.lastEventID = domain.lastEventID.map { Int64(bitPattern: $0) }
        self.accessState = domain.accessState.rawValue
        self.lastError = domain.lastError
    }

    public func toDomain() -> WatchedFolder? {
        guard let uuid = UUID(uuidString: id),
              let state = WatchedFolder.AccessState(rawValue: accessState) else {
            return nil
        }
        return WatchedFolder(
            id: uuid,
            displayName: displayName,
            bookmarkData: bookmarkData,
            lastResolvedPath: lastResolvedPath,
            isEnabled: isEnabled,
            recursive: recursive,
            addedAt: addedAt,
            lastScanStartedAt: lastScanStartedAt,
            lastScanCompletedAt: lastScanCompletedAt,
            lastEventID: lastEventID.map { UInt64(bitPattern: $0) },
            accessState: state,
            lastError: lastError
        )
    }
}
