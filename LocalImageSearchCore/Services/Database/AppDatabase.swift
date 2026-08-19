import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public let dbWriter: any DatabaseWriter

    public init(_ dbWriter: any DatabaseWriter) throws {
        self.dbWriter = dbWriter
        try migrator.migrate(dbWriter)
    }

    public static func inMemory() throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.busyMode = .timeout(5.0)
        let dbQueue = try DatabaseQueue(configuration: config)
        return try AppDatabase(dbQueue)
    }

    public static func persistent(at url: URL) throws -> AppDatabase {
        var config = Configuration()
        config.foreignKeysEnabled = true
        config.busyMode = .timeout(10.0)
        let dbPool = try DatabasePool(path: url.path, configuration: config)
        return try AppDatabase(dbPool)
    }

    public static func defaultDatabaseURL() throws -> URL {
        let appSupport = try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = appSupport.appendingPathComponent("LocalImageSearch", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("catalog.sqlite")
    }

    public var migrator: DatabaseMigrator {
        DatabaseMigrations.migrator
    }

    public func read<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try dbWriter.read(block)
    }

    public func write<T: Sendable>(_ block: @Sendable (Database) throws -> T) throws -> T {
        try dbWriter.write(block)
    }
}
