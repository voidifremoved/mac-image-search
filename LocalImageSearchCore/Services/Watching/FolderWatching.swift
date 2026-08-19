import Foundation

public protocol FolderWatching: Sendable {
    func events() -> AsyncStream<FolderChangeEvent>
    func replaceRoots(_ roots: [ResolvedFolder]) async throws
}
