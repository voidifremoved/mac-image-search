import Testing
import Foundation
import CoreGraphics
import ImageIO
@testable import LocalImageSearchCore

@Suite("Discovery & Imaging Tests")
struct DiscoveryTests {
    @Test("Discovery finds image files and calculates streaming SHA256")
    func testDiscoveryAndHashing() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        // Create a test 10x10 PNG image file
        let imageURL = tempDir.appendingPathComponent("test_photo.png")
        let width = 10
        let height = 10
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setFillColor(CGColor(red: 1, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let cgImage = context.makeImage()!

        let destination = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, cgImage, nil)
        CGImageDestinationFinalize(destination)

        // Create an unsupported SVG dummy file
        let svgURL = tempDir.appendingPathComponent("icon.svg")
        try "<svg></svg>".write(to: svgURL, atomically: true, encoding: .utf8)

        // Enumerate
        let resolved = ResolvedFolder(folderID: UUID(), url: tempDir, recursive: true)
        let enumerator = FileEnumerator()
        let items = try enumerator.enumerate(root: resolved)

        #expect(items.count == 1)
        #expect(items.first?.relativePath == "test_photo.png")
        #expect(items.first?.pixelWidth == 10)
        #expect(items.first?.pixelHeight == 10)

        // Test streaming hash
        let hash = try FileIdentityReader.computeStreamingSHA256(at: imageURL)
        #expect(!hash.isEmpty)
        #expect(hash.count == 32)
    }

    @Test("ThumbnailStore generates and caches image thumbnails")
    func testThumbnailStore() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let imageURL = tempDir.appendingPathComponent("sample.png")
        let context = CGContext(
            data: nil,
            width: 50,
            height: 50,
            bitsPerComponent: 8,
            bytesPerRow: 50 * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        let cgImage = context.makeImage()!
        let dest = CGImageDestinationCreateWithURL(imageURL as CFURL, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, cgImage, nil)
        CGImageDestinationFinalize(dest)

        let store = ThumbnailStore(cacheDirectory: tempDir.appendingPathComponent("ThumbCache"))
        let thumb1 = store.thumbnail(for: "sample_sha", sourceURL: imageURL, maxPixelSize: 32)
        #expect(thumb1 != nil)

        // Second call retrieves from memory cache
        let thumb2 = store.thumbnail(for: "sample_sha", sourceURL: imageURL, maxPixelSize: 32)
        #expect(thumb2 != nil)
    }
}
