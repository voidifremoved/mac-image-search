import Foundation

public struct FolderChangeEvent: Sendable, Equatable {
    public enum EventKind: Sendable, Equatable {
        case itemCreated(URL)
        case itemModified(URL)
        case itemRenamed(from: URL, to: URL)
        case itemRemoved(URL)
        case rootRescanRequired(UUID)
    }

    public let folderID: UUID
    public let kind: EventKind
    public let eventID: UInt64?

    public init(folderID: UUID, kind: EventKind, eventID: UInt64? = nil) {
        self.folderID = folderID
        self.kind = kind
        self.eventID = eventID
    }
}
