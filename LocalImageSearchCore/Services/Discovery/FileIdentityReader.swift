import Foundation
import CryptoKit

public struct FileMetadata: Sendable {
    public let fileSize: Int64
    public let modifiedAt: Date
    public let createdAt: Date?
    public let fileResourceID: Data?
}

public enum FileIdentityReader {
    public static func readMetadata(at url: URL) throws -> FileMetadata {
        let values = try url.resourceValues(forKeys: [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileResourceIdentifierKey
        ])

        let size = Int64(values.fileSize ?? 0)
        let modified = values.contentModificationDate ?? Date()
        let created = values.creationDate
        let resourceIDData = stableResourceIdentifierData(values.fileResourceIdentifier)

        return FileMetadata(
            fileSize: size,
            modifiedAt: modified,
            createdAt: created,
            fileResourceID: resourceIDData
        )
    }

    /// URLResourceValues exposes the file identifier as a type-erased value. Copying
    /// the bytes of that container records process-specific pointers, not the identifier,
    /// so the value appeared to change on every launch. On Apple filesystems the payload
    /// is normally NSData; the fallbacks keep identifiers stable on other volumes.
    public static func stableResourceIdentifierData(_ identifier: Any?) -> Data? {
        guard let identifier else { return nil }
        if let data = identifier as? Data { return data }
        if let uuid = identifier as? UUID { return withUnsafeBytes(of: uuid.uuid) { Data($0) } }
        if let number = identifier as? NSNumber {
            return number.stringValue.data(using: .utf8)
        }
        return String(describing: identifier).data(using: .utf8)
    }

    public static func computeStreamingSHA256(at url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var hasher = SHA256()
        let bufferSize = 64 * 1024 // 64 KB chunks

        while autoreleasepool(invoking: {
            guard let data = try? handle.read(upToCount: bufferSize), !data.isEmpty else {
                return false
            }
            hasher.update(data: data)
            return true
        }) {}

        let digest = hasher.finalize()
        return Data(digest)
    }

    public static func isFileStable(at url: URL, delaySeconds: TimeInterval = 0.5) async throws -> Bool {
        let m1 = try readMetadata(at: url)
        // Files that have not changed recently are already stable. Avoid a fixed delay
        // for every recovered/persisted job: 130 files at 0.2 seconds each added roughly
        // 26 seconds to startup even when no vision request was necessary.
        if Date().timeIntervalSince(m1.modifiedAt) > max(2, delaySeconds * 2) {
            return true
        }
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        let m2 = try readMetadata(at: url)
        return m1.fileSize == m2.fileSize && m1.modifiedAt == m2.modifiedAt
    }
}
