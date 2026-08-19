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
        var resourceIDData: Data? = nil
        if let resID = values.fileResourceIdentifier {
            resourceIDData = withUnsafeBytes(of: resID) { Data($0) }
        }

        return FileMetadata(
            fileSize: size,
            modifiedAt: modified,
            createdAt: created,
            fileResourceID: resourceIDData
        )
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
        try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
        let m2 = try readMetadata(at: url)
        return m1.fileSize == m2.fileSize && m1.modifiedAt == m2.modifiedAt
    }
}
