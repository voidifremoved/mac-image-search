import Foundation
import GRDB

public struct ImageAssetRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "image_asset"

    public var id: Int64?
    public var folderId: String
    public var relativePath: String
    public var normalizedRelativePath: String
    public var fileResourceId: Data?
    public var contentId: Int64?
    public var fileSize: Int64
    public var modifiedAt: Date
    public var createdAt: Date?
    public var pixelWidth: Int?
    public var pixelHeight: Int?
    public var uti: String?
    public var discoveredAt: Date
    public var lastSeenScanId: String
    public var availability: String
    public var lastError: String?

    public enum CodingKeys: String, CodingKey {
        case id
        case folderId = "folder_id"
        case relativePath = "relative_path"
        case normalizedRelativePath = "normalized_relative_path"
        case fileResourceId = "file_resource_id"
        case contentId = "content_id"
        case fileSize = "file_size"
        case modifiedAt = "modified_at"
        case createdAt = "created_at"
        case pixelWidth = "pixel_width"
        case pixelHeight = "pixel_height"
        case uti
        case discoveredAt = "discovered_at"
        case lastSeenScanId = "last_seen_scan_id"
        case availability
        case lastError = "last_error"
    }

    public enum Columns: String, ColumnExpression {
        case id, folderId = "folder_id", relativePath = "relative_path"
        case normalizedRelativePath = "normalized_relative_path"
        case fileResourceId = "file_resource_id", contentId = "content_id"
        case fileSize = "file_size", modifiedAt = "modified_at", createdAt = "created_at"
        case pixelWidth = "pixel_width", pixelHeight = "pixel_height", uti
        case discoveredAt = "discovered_at", lastSeenScanId = "last_seen_scan_id"
        case availability, lastError = "last_error"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    public init(from domain: ImageAsset) {
        self.id = domain.id
        self.folderId = domain.folderID.uuidString
        self.relativePath = domain.relativePath
        self.normalizedRelativePath = domain.normalizedRelativePath
        self.fileResourceId = domain.fileResourceID
        self.contentId = domain.contentID
        self.fileSize = domain.fileSize
        self.modifiedAt = domain.modifiedAt
        self.createdAt = domain.createdAt
        self.pixelWidth = domain.pixelWidth
        self.pixelHeight = domain.pixelHeight
        self.uti = domain.uti
        self.discoveredAt = domain.discoveredAt
        self.lastSeenScanId = domain.lastSeenScanID.uuidString
        self.availability = domain.availability.rawValue
        self.lastError = domain.lastError
    }

    public func toDomain() -> ImageAsset? {
        guard let folderUUID = UUID(uuidString: folderId),
              let scanUUID = UUID(uuidString: lastSeenScanId),
              let avail = ImageAsset.Availability(rawValue: availability) else {
            return nil
        }
        return ImageAsset(
            id: id,
            folderID: folderUUID,
            relativePath: relativePath,
            normalizedRelativePath: normalizedRelativePath,
            fileResourceID: fileResourceId,
            contentID: contentId,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            createdAt: createdAt,
            pixelWidth: pixelWidth,
            pixelHeight: pixelHeight,
            uti: uti,
            discoveredAt: discoveredAt,
            lastSeenScanID: scanUUID,
            availability: avail,
            lastError: lastError
        )
    }
}
