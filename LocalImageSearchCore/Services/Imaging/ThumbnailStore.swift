import Foundation
import CoreGraphics
import ImageIO

#if os(macOS)
import AppKit
public typealias PlatformImage = NSImage
#else
import UIKit
public typealias PlatformImage = UIImage
#endif

public final class ThumbnailStore: @unchecked Sendable {
    private let cacheDirectory: URL
    private let memoryCache = NSCache<NSString, PlatformImage>()

    public init(cacheDirectory: URL? = nil) {
        if let cacheDirectory {
            self.cacheDirectory = cacheDirectory
        } else {
            let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            self.cacheDirectory = caches.appendingPathComponent("LocalImageSearch/Thumbnails", isDirectory: true)
        }
        try? FileManager.default.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
        memoryCache.countLimit = 500
    }

    public func thumbnail(for sha256Hex: String, sourceURL: URL, maxPixelSize: CGFloat = 320) -> PlatformImage? {
        // A result-row thumbnail and the inspector preview need separate cache entries.
        // Keying only by content caused whichever size loaded first (usually 240 px) to
        // be stretched across the large inspector preview.
        let pixelSize = max(1, Int(maxPixelSize.rounded(.up)))
        let cacheIdentifier = "\(sha256Hex)-p\(pixelSize)"
        let key = NSString(string: cacheIdentifier)
        if let cached = memoryCache.object(forKey: key) {
            return cached
        }

        let diskFile = cacheDirectory.appendingPathComponent("\(cacheIdentifier).jpg")
        if let diskImage = PlatformImage(contentsOfFile: diskFile.path) {
            memoryCache.setObject(diskImage, forKey: key)
            return diskImage
        }

        // Generate thumbnail
        guard let generated = generateThumbnail(from: sourceURL, maxPixelSize: CGFloat(pixelSize)) else {
            return nil
        }

        // Cache to memory and disk
        memoryCache.setObject(generated, forKey: key)
        saveToDisk(image: generated, to: diskFile)

        return generated
    }

    private func generateThumbnail(from url: URL, maxPixelSize: CGFloat) -> PlatformImage? {
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }

        #if os(macOS)
        let size = NSSize(width: cgImage.width, height: cgImage.height)
        return NSImage(cgImage: cgImage, size: size)
        #else
        return UIImage(cgImage: cgImage)
        #endif
    }

    private func saveToDisk(image: PlatformImage, to url: URL) {
        #if os(macOS)
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let jpeg = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.92]) else {
            return
        }
        try? jpeg.write(to: url)
        #endif
    }
}
