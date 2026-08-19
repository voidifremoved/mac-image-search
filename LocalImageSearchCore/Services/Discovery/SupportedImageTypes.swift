import Foundation
import UniformTypeIdentifiers
import ImageIO

public enum SupportedImageTypes {
    public static let maxFileSizeBytes: Int64 = 250 * 1024 * 1024 // 250 MB safety cap

    public static let skippedDirectories: Set<String> = [
        ".trash", ".git", "node_modules", ".svn", ".hg", "cdata"
    ]

    public static let unsupportedExtensions: Set<String> = [
        "svg", "pdf", "ai", "psd", "eps", "blend"
    ]

    public static func isSupportedImage(url: URL) -> Bool {
        // Skip hidden files
        if url.lastPathComponent.hasPrefix(".") { return false }

        // Check extension blocklist
        let ext = url.pathExtension.lowercased()
        if unsupportedExtensions.contains(ext) { return false }

        // Check UTType
        guard let utType = UTType(filenameExtension: ext) else {
            return probeImageIO(url: url)
        }

        if utType.conforms(to: .svg) || utType.conforms(to: .pdf) {
            return false
        }

        guard utType.conforms(to: .image) else {
            return false
        }

        return true
    }

    public static func probeImageIO(url: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else {
            return false
        }
        return CGImageSourceGetCount(source) > 0
    }
}
