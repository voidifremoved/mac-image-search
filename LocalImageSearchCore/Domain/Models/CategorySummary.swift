import Foundation

public struct CategorySummary: Identifiable, Sendable, Equatable, Hashable {
    public var id: String { name.lowercased() }
    public let name: String
    public let imageCount: Int

    public init(name: String, imageCount: Int) {
        self.name = name
        self.imageCount = imageCount
    }
}
