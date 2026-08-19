import Foundation

public struct ResolvedFolder: Sendable, Equatable {
    public let folderID: UUID
    public let url: URL
    public let recursive: Bool

    public init(folderID: UUID, url: URL, recursive: Bool = true) {
        self.folderID = folderID
        self.url = url
        self.recursive = recursive
    }
}
