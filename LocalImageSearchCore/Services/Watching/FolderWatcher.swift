import Foundation
import CoreServices

public final class FolderWatcher: FolderWatching, @unchecked Sendable {
    private var streamRef: FSEventStreamRef?
    private var roots: [ResolvedFolder] = []
    private var continuation: AsyncStream<FolderChangeEvent>.Continuation?
    private let queue = DispatchQueue(label: "com.localimagesearch.folderwatcher")

    public init() {}

    public func events() -> AsyncStream<FolderChangeEvent> {
        AsyncStream { continuation in
            self.queue.sync {
                self.continuation = continuation
            }

            continuation.onTermination = { [weak self] _ in
                self?.queue.async {
                    self?.stopStream()
                }
            }
        }
    }

    public func replaceRoots(_ roots: [ResolvedFolder]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                self.roots = roots
                self.stopStream()

                guard !roots.isEmpty else {
                    continuation.resume()
                    return
                }

                var pathsToWatch: [CFString] = []
                for r in roots {
                    pathsToWatch.append(r.url.path as CFString)
                }

                var context = FSEventStreamContext(
                    version: 0,
                    info: Unmanaged.passUnretained(self).toOpaque(),
                    retain: nil,
                    release: nil,
                    copyDescription: nil
                )

                let flags: FSEventStreamCreateFlags = UInt32(
                    kFSEventStreamCreateFlagUseCFTypes |
                    kFSEventStreamCreateFlagFileEvents |
                    kFSEventStreamCreateFlagNoDefer
                )

                let callback: FSEventStreamCallback = { (streamRef, clientCallBackInfo, numEvents, eventPaths, eventFlags, eventIds) in
                    guard let clientCallBackInfo else { return }
                    let watcher = Unmanaged<FolderWatcher>.fromOpaque(clientCallBackInfo).takeUnretainedValue()
                    watcher.handleEvents(
                        numEvents: numEvents,
                        eventPaths: eventPaths,
                        eventFlags: eventFlags,
                        eventIds: eventIds
                    )
                }

                guard let stream = FSEventStreamCreate(
                    kCFAllocatorDefault,
                    callback,
                    &context,
                    pathsToWatch as CFArray,
                    FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
                    1.0,
                    flags
                ) else {
                    continuation.resume()
                    return
                }

                self.streamRef = stream
                FSEventStreamSetDispatchQueue(stream, self.queue)
                FSEventStreamStart(stream)
                continuation.resume()
            }
        }
    }

    private func handleEvents(
        numEvents: Int,
        eventPaths: UnsafeMutableRawPointer,
        eventFlags: UnsafePointer<FSEventStreamEventFlags>,
        eventIds: UnsafePointer<FSEventStreamEventId>
    ) {
        guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

        for i in 0..<numEvents {
            let path = paths[i]
            let flag = eventFlags[i]
            let eventID = eventIds[i]
            let fileURL = URL(fileURLWithPath: path)

            guard let matchedRoot = roots.first(where: { path.hasPrefix($0.url.path) }) else {
                continue
            }

            let kind: FolderChangeEvent.EventKind
            let mustRescan = (flag & UInt32(kFSEventStreamEventFlagMustScanSubDirs)) != 0 ||
                             (flag & UInt32(kFSEventStreamEventFlagRootChanged)) != 0

            if mustRescan {
                kind = .rootRescanRequired(matchedRoot.folderID)
            } else if (flag & UInt32(kFSEventStreamEventFlagItemRemoved)) != 0 {
                kind = .itemRemoved(fileURL)
            } else if (flag & UInt32(kFSEventStreamEventFlagItemCreated)) != 0 {
                kind = .itemCreated(fileURL)
            } else {
                kind = .itemModified(fileURL)
            }

            continuation?.yield(FolderChangeEvent(folderID: matchedRoot.folderID, kind: kind, eventID: UInt64(eventID)))
        }
    }

    private func stopStream() {
        if let streamRef {
            FSEventStreamStop(streamRef)
            FSEventStreamInvalidate(streamRef)
            FSEventStreamRelease(streamRef)
            self.streamRef = nil
        }
    }

    deinit {
        stopStream()
    }
}
