import Foundation
import GRDB

public struct ImageAnalysisRecord: Codable, FetchableRecord, PersistableRecord, TableRecord {
    public static let databaseTableName = "image_analysis"

    public var id: Int64?
    public var contentId: Int64
    public var providerKind: String
    public var baseUrlFingerprint: String
    public var model: String
    public var promptVersion: Int
    public var schemaVersion: Int
    public var description: String
    public var shortTitle: String
    public var categoriesJson: String
    public var objectsJson: String
    public var scene: String?
    public var dominantColorsJson: String
    public var visibleText: String?
    public var peopleCount: Int?
    public var timeOfDay: String?
    public var searchableText: String
    public var rawResponseJson: String?
    public var createdAt: Date
    public var isCurrent: Bool

    public enum CodingKeys: String, CodingKey {
        case id
        case contentId = "content_id"
        case providerKind = "provider_kind"
        case baseUrlFingerprint = "base_url_fingerprint"
        case model
        case promptVersion = "prompt_version"
        case schemaVersion = "schema_version"
        case description
        case shortTitle = "short_title"
        case categoriesJson = "categories_json"
        case objectsJson = "objects_json"
        case scene
        case dominantColorsJson = "dominant_colors_json"
        case visibleText = "visible_text"
        case peopleCount = "people_count"
        case timeOfDay = "time_of_day"
        case searchableText = "searchable_text"
        case rawResponseJson = "raw_response_json"
        case createdAt = "created_at"
        case isCurrent = "is_current"
    }

    public enum Columns: String, ColumnExpression {
        case id, contentId = "content_id", providerKind = "provider_kind"
        case baseUrlFingerprint = "base_url_fingerprint", model
        case promptVersion = "prompt_version", schemaVersion = "schema_version"
        case description, shortTitle = "short_title", categoriesJson = "categories_json"
        case objectsJson = "objects_json", scene, dominantColorsJson = "dominant_colors_json"
        case visibleText = "visible_text", peopleCount = "people_count", timeOfDay = "time_of_day"
        case searchableText = "searchable_text", rawResponseJson = "raw_response_json"
        case createdAt = "created_at", isCurrent = "is_current"
    }

    public mutating func didInsert(_ inserted: InsertionSuccess) {
        id = inserted.rowID
    }

    public init(from domain: ImageAnalysis) throws {
        self.id = domain.id
        self.contentId = domain.contentID
        self.providerKind = domain.providerKind
        self.baseUrlFingerprint = domain.baseURLFingerprint
        self.model = domain.model
        self.promptVersion = domain.promptVersion
        self.schemaVersion = domain.schemaVersion
        self.description = domain.description
        self.shortTitle = domain.shortTitle
        self.categoriesJson = String(data: try JSONEncoder().encode(domain.categories), encoding: .utf8) ?? "[]"
        self.objectsJson = String(data: try JSONEncoder().encode(domain.objects), encoding: .utf8) ?? "[]"
        self.scene = domain.scene
        self.dominantColorsJson = String(data: try JSONEncoder().encode(domain.dominantColors), encoding: .utf8) ?? "[]"
        self.visibleText = domain.visibleText
        self.peopleCount = domain.peopleCount
        self.timeOfDay = domain.timeOfDay
        self.searchableText = domain.searchableText
        self.rawResponseJson = domain.rawResponseJSON
        self.createdAt = domain.createdAt
        self.isCurrent = domain.isCurrent
    }

    public func toDomain() -> ImageAnalysis {
        let cats = (categoriesJson.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
        let objs = (objectsJson.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []
        let colors = (dominantColorsJson.data(using: .utf8).flatMap { try? JSONDecoder().decode([String].self, from: $0) }) ?? []

        return ImageAnalysis(
            id: id,
            contentID: contentId,
            providerKind: providerKind,
            baseURLFingerprint: baseUrlFingerprint,
            model: model,
            promptVersion: promptVersion,
            schemaVersion: schemaVersion,
            description: description,
            shortTitle: shortTitle,
            categories: cats,
            objects: objs,
            scene: scene,
            dominantColors: colors,
            visibleText: visibleText,
            peopleCount: peopleCount,
            timeOfDay: timeOfDay,
            searchableText: searchableText,
            rawResponseJSON: rawResponseJson,
            createdAt: createdAt,
            isCurrent: isCurrent
        )
    }
}
