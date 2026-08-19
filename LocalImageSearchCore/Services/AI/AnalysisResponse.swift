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
        case description
        case categories
        case objects
        case scene
        case dominantColors = "dominant_colors"
        case visibleText = "visible_text"
        case peopleCount = "people_count"
        case timeOfDay = "time_of_day"
        case searchKeywords = "search_keywords"
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
            components.append("text: \(visibleText)")
        }
        if !searchKeywords.isEmpty {
            components.append("keywords: \(searchKeywords.joined(separator: ", "))")
        }
        return components.joined(separator: "\n")
    }
}
