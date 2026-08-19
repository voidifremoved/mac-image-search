import Foundation
import ImageIO

public final class FileEnumerator: Sendable {
    public init() {}

    public struct DiscoveredItem: Sendable {
        public let url: URL
        public let relativePath: String
        public let normalizedRelativePath: String
        public let metadata: FileMetadata
        public let pixelWidth: Int?
        public let pixelHeight: Int?
        public let uti: String?
    }

    public func enumerate(root: ResolvedFolder) throws -> [DiscoveredItem] {
        let rootURL = root.url
        let options: FileManager.DirectoryEnumerationOptions = root.recursive
            ? [.skipsHiddenFiles, .skipsPackageDescendants]
            : [.skipsHiddenFiles, .skipsPackageDescendants, .skipsSubdirectoryDescendants]

        let keys: [URLResourceKey] = [
            .fileSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .fileResourceIdentifierKey,
            .isDirectoryKey,
            .isPackageKey,
            .isSymbolicLinkKey,
            .typeIdentifierKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: rootURL,
            includingPropertiesForKeys: keys,
            options: options
        ) else {
            return []
        }

        var results: [DiscoveredItem] = []
        let rootPath = rootURL.standardizedFileURL.path

        for case let fileURL as URL in enumerator {
            // Fetch identity separately from basic file facts. Some filesystems and CI
            // volumes do not support every requested resource key; one unavailable key
            // must not cause an otherwise valid image to disappear from discovery.
            let basicKeys: Set<URLResourceKey> = [.isDirectoryKey, .isPackageKey, .isSymbolicLinkKey]
            let metadataKeys: Set<URLResourceKey> = [
                .fileSizeKey, .contentModificationDateKey, .creationDateKey,
                .fileResourceIdentifierKey, .typeIdentifierKey
            ]
            let basicValues = try? fileURL.resourceValues(forKeys: basicKeys)
            let resourceValues = try? fileURL.resourceValues(forKeys: metadataKeys)
            let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path)

            if basicValues?.isDirectory == true || basicValues?.isPackage == true || basicValues?.isSymbolicLink == true {
                continue
            }

            let attributeSize = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            let size = Int64(resourceValues?.fileSize ?? 0) > 0
                ? Int64(resourceValues?.fileSize ?? 0)
                : attributeSize
            if size <= 0 || size > SupportedImageTypes.maxFileSizeBytes {
                continue
            }

            guard SupportedImageTypes.isSupportedImage(url: fileURL) else {
                continue
            }

            let fullPath = fileURL.standardizedFileURL.path
            var relativePath = fullPath
            if fullPath.hasPrefix(rootPath) {
                let suffixIndex = fullPath.index(fullPath.startIndex, offsetBy: rootPath.count)
                relativePath = String(fullPath[suffixIndex...]).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            }

            let normalizedRelative = relativePath.precomposedStringWithCanonicalMapping

            var resourceIDData: Data? = nil
            if let resID = resourceValues?.fileResourceIdentifier {
                resourceIDData = withUnsafeBytes(of: resID) { Data($0) }
            }

            let metadata = FileMetadata(
                fileSize: size,
                modifiedAt: resourceValues?.contentModificationDate ?? (attributes?[.modificationDate] as? Date) ?? Date(),
                createdAt: resourceValues?.creationDate ?? (attributes?[.creationDate] as? Date),
                fileResourceID: resourceIDData
            )

            // Read dimensions from Image I/O quickly without decoding pixels
            var pixelWidth: Int? = nil
            var pixelHeight: Int? = nil
            if let imageSource = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
               let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [CFString: Any] {
                pixelWidth = properties[kCGImagePropertyPixelWidth] as? Int
                pixelHeight = properties[kCGImagePropertyPixelHeight] as? Int
            }

            results.append(DiscoveredItem(
                url: fileURL,
                relativePath: relativePath,
                normalizedRelativePath: normalizedRelative,
                metadata: metadata,
                pixelWidth: pixelWidth,
                pixelHeight: pixelHeight,
                uti: resourceValues?.typeIdentifier
            ))
        }

        return results
    }
}
