import Foundation
import GRDB

public final class AppDatabase: Sendable {
    public static let bundleIdentifier = "com.localimagesearch.app"
    public static let supportDirectoryName = "LocalImageSearch"
    public static let databaseFilename = "catalog.sqlite"

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

        // A sandboxed installed app resolves Application Support inside its container.
        // A raw SwiftPM development build is unsandboxed; when an installed catalog
        // already exists, point that build at the same durable database instead of
        // presenting a second empty library.
        if !appSupport.path.contains("/Library/Containers/\(bundleIdentifier)/Data/") {
            let installedDatabase = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Containers/\(bundleIdentifier)/Data/Library/Application Support", isDirectory: true)
                .appendingPathComponent(supportDirectoryName, isDirectory: true)
                .appendingPathComponent(databaseFilename)
            if FileManager.default.fileExists(atPath: installedDatabase.path) {
                return installedDatabase
            }
        }

        let directory = appSupport.appendingPathComponent(supportDirectoryName, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(databaseFilename)
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
