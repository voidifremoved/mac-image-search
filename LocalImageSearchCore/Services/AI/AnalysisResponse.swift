import Foundation

public struct AnalysisResponse: Sendable, Codable, Equatable {
    public let shortTitle: String
    public let description: String
    public let categories: [String]
    public let objects: [String]
    public let scene: String?
    public let dominantColors: [String]
    public let visibleText: String?
    public let peopleCount: Int?
    public let timeOfDay: String?
    public let searchKeywords: [String]

    public enum CodingKeys: String, CodingKey {
        case shortTitle = "short_title"
        case summary
        case legacyDescription = "description"
        case categories
        case objects
        case scene
        case dominantColors = "dominant_colors"
        case fullText = "full_text"
        case legacyVisibleText = "visible_text"
        case peopleCount = "people_count"
        case timeOfDay = "time_of_day"
        case searchKeywords = "search_keywords"
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        shortTitle = try container.decode(String.self, forKey: .shortTitle)
        description = try container.decodeIfPresent(String.self, forKey: .summary)
            ?? container.decode(String.self, forKey: .legacyDescription)
        categories = try container.decode([String].self, forKey: .categories)
        objects = try container.decode([String].self, forKey: .objects)
        scene = try container.decodeIfPresent(String.self, forKey: .scene)
        dominantColors = try container.decodeIfPresent([String].self, forKey: .dominantColors) ?? []
        visibleText = try container.decodeIfPresent(String.self, forKey: .fullText)
            ?? container.decodeIfPresent(String.self, forKey: .legacyVisibleText)
        peopleCount = try container.decodeIfPresent(Int.self, forKey: .peopleCount)
        timeOfDay = try container.decodeIfPresent(String.self, forKey: .timeOfDay)
        searchKeywords = try container.decodeIfPresent([String].self, forKey: .searchKeywords) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(shortTitle, forKey: .shortTitle)
        try container.encode(description, forKey: .summary)
        try container.encode(categories, forKey: .categories)
        try container.encode(objects, forKey: .objects)
        try container.encodeIfPresent(scene, forKey: .scene)
        try container.encode(dominantColors, forKey: .dominantColors)
        try container.encodeIfPresent(visibleText, forKey: .fullText)
        try container.encodeIfPresent(peopleCount, forKey: .peopleCount)
        try container.encodeIfPresent(timeOfDay, forKey: .timeOfDay)
        try container.encode(searchKeywords, forKey: .searchKeywords)
    }

    public init(
        shortTitle: String,
        description: String,
        categories: [String],
        objects: [String],
        scene: String? = nil,
        dominantColors: [String] = [],
        visibleText: String? = nil,
        peopleCount: Int? = nil,
        timeOfDay: String? = nil,
        searchKeywords: [String] = []
    ) {
        self.shortTitle = shortTitle
        self.description = description
        self.categories = categories
        self.objects = objects
        self.scene = scene
        self.dominantColors = dominantColors
        self.visibleText = visibleText
        self.peopleCount = peopleCount
        self.timeOfDay = timeOfDay
        self.searchKeywords = searchKeywords
    }

    public func buildSearchableText() -> String {
        var components: [String] = []
        components.append("title: \(shortTitle)")
        components.append("description: \(description)")
        if !categories.isEmpty {
            components.append("categories: \(categories.joined(separator: ", "))")
        }
        if !objects.isEmpty {
            components.append("objects: \(objects.joined(separator: ", "))")
        }
        if let scene, !scene.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append("scene: \(scene)")
        }
        if !dominantColors.isEmpty {
            components.append("colors: \(dominantColors.joined(separator: ", "))")
        }
        if let visibleText, !visibleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            components.append("full text transcription:\n\(visibleText)")
        }
        if !searchKeywords.isEmpty {
            components.append("keywords: \(searchKeywords.joined(separator: ", "))")
        }
        return components.joined(separator: "\n")
    }
}
