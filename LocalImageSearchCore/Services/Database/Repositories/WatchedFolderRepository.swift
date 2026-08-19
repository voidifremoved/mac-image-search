import Foundation
import GRDB

public struct WatchedFolderRepository: Sendable {
    private let database: AppDatabase

    public init(database: AppDatabase) {
        self.database = database
    }

    public func save(_ folder: WatchedFolder) throws {
        try database.write { db in
            let record = WatchedFolderRecord(from: folder)
            try record.save(db)
        }
    }

    public func get(id: UUID) throws -> WatchedFolder? {
        try database.read { db in
            try WatchedFolderRecord.fetchOne(db, key: id.uuidString)?.toDomain()
        }
    }

    public func getAll() throws -> [WatchedFolder] {
        try database.read { db in
            try WatchedFolderRecord.fetchAll(db).compactMap { $0.toDomain() }
        }
    }

    public func getEnabled() throws -> [WatchedFolder] {
        try database.read { db in
            try WatchedFolderRecord
                .filter(WatchedFolderRecord.Columns.isEnabled == true)
                .fetchAll(db)
                .compactMap { $0.toDomain() }
        }
    }

    public func delete(id: UUID) throws {
        try database.write { db in
            _ = try WatchedFolderRecord.deleteOne(db, key: id.uuidString)
        }
    }

    public func updateAccessState(id: UUID, state: WatchedFolder.AccessState, error: String? = nil) throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE watched_folder SET access_state = ?, last_error = ? WHERE id = ?",
                arguments: [state.rawValue, error, id.uuidString]
            )
        }
    }

    public func recordScanStarted(id: UUID, at date: Date = Date()) throws {
        try database.write { db in
            try db.execute(
                sql: "UPDATE watched_folder SET last_scan_started_at = ? WHERE id = ?",
                arguments: [date, id.uuidString]
            )
        }
    }

    public func recordScanCompleted(id: UUID, at date: Date = Date(), lastEventID: UInt64? = nil) throws {
        try database.write { db in
            let eventArg: Int64? = lastEventID.map { Int64(bitPattern: $0) }
            try db.execute(
                sql: "UPDATE watched_folder SET last_scan_completed_at = ?, last_event_id = COALESCE(?, last_event_id) WHERE id = ?",
                arguments: [date, eventArg, id.uuidString]
            )
        }
    }
}
