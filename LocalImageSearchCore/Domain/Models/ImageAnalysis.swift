import Foundation

public struct ImageAnalysis: Identifiable, Sendable, Codable, Equatable, Hashable {
    public var id: Int64?
    public var contentID: Int64
    public var providerKind: String
    public var baseURLFingerprint: String
    public var model: String
    public var promptVersion: Int
    public var schemaVersion: Int
    public var description: String
    public var shortTitle: String
    public var categories: [String]
    public var objects: [String]
    public var scene: String?
    public var dominantColors: [String]
    public var visibleText: String?
    public var peopleCount: Int?
    public var timeOfDay: String?
    public var searchableText: String
    public var rawResponseJSON: String?
    public var createdAt: Date
    public var isCurrent: Bool

    public init(
        id: Int64? = nil,
        contentID: Int64,
        providerKind: String,
        baseURLFingerprint: String,
        model: String,
        promptVersion: Int = 1,
        schemaVersion: Int = 1,
        description: String,
        shortTitle: String,
        categories: [String],
        objects: [String],
        scene: String? = nil,
        dominantColors: [String] = [],
        visibleText: String? = nil,
        peopleCount: Int? = nil,
        timeOfDay: String? = nil,
        searchableText: String,
        rawResponseJSON: String? = nil,
        createdAt: Date = Date(),
        isCurrent: Bool = true
    ) {
        self.id = id
        self.contentID = contentID
        self.providerKind = providerKind
        self.baseURLFingerprint = baseURLFingerprint
        self.model = model
        self.promptVersion = promptVersion
        self.schemaVersion = schemaVersion
        self.description = description
        self.shortTitle = shortTitle
        self.categories = categories
        self.objects = objects
        self.scene = scene
        self.dominantColors = dominantColors
        self.visibleText = visibleText
        self.peopleCount = peopleCount
        self.timeOfDay = timeOfDay
        self.searchableText = searchableText
        self.rawResponseJSON = rawResponseJSON
        self.createdAt = createdAt
        self.isCurrent = isCurrent
    }
}
