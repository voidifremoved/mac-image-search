import Foundation
import os

public enum AppLogger {
    private static let subsystem = "com.localimagesearch.app"

    public static let general = Logger(subsystem: subsystem, category: "general")
    public static let database = Logger(subsystem: subsystem, category: "database")
    public static let folderAccess = Logger(subsystem: subsystem, category: "folderAccess")
    public static let discovery = Logger(subsystem: subsystem, category: "discovery")
    public static let watching = Logger(subsystem: subsystem, category: "watching")
    public static let imaging = Logger(subsystem: subsystem, category: "imaging")
    public static let ai = Logger(subsystem: subsystem, category: "ai")
    public static let embedding = Logger(subsystem: subsystem, category: "embedding")
    public static let indexing = Logger(subsystem: subsystem, category: "indexing")
    public static let search = Logger(subsystem: subsystem, category: "search")
    public static let security = Logger(subsystem: subsystem, category: "security")
}
