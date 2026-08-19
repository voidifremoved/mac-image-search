import Foundation

public struct ImageAsset: Identifiable, Sendable, Codable, Equatable, Hashable {
    public enum Availability: String, Sendable, Codable {
        case present
        case missing
        case unreadable
        case unsupported
    }

    public var id: Int64?
    public var folderID: UUID
    public var relativePath: String
    public var normalizedRelativePath: String
    public var fileResourceID: Data?
    public var contentID: Int64?
    public var fileSize: Int64
    public var modifiedAt: Date
    public var createdAt: Date?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var uti: String?
    public var discoveredAt: Date
    public var lastSeenScanID: UUID
    public var availability: Availability
    public var lastError: String?

    public init(
        id: Int64? = nil,
        folderID: UUID,
        relativePath: String,
        normalizedRelativePath: String,
        fileResourceID: Data? = nil,
        contentID: Int64? = nil,
        fileSize: Int64,
        modifiedAt: Date,
        createdAt: Date? = nil,
        pixelWidth: Int? = nil,
        pixelHeight: Int? = nil,
        uti: String? = nil,
        discoveredAt: Date = Date(),
        lastSeenScanID: UUID,
        availability: Availability = .present,
        lastError: String? = nil
    ) {
        self.id = id
        self.folderID = folderID
        self.relativePath = relativePath
        self.normalizedRelativePath = normalizedRelativePath
        self.fileResourceID = fileResourceID
        self.contentID = contentID
        self.fileSize = fileSize
        self.modifiedAt = modifiedAt
        self.createdAt = createdAt
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.uti = uti
        self.discoveredAt = discoveredAt
        self.lastSeenScanID = lastSeenScanID
        self.availability = availability
        self.lastError = lastError
    }
}
