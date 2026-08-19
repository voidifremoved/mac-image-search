import Foundation
import CoreGraphics
import ImageIO

public enum AnalysisPreviewBuilder {
    public static let maxLongEdgePixels: CGFloat = 1600
    public static let maxPayloadBytes: Int = 8 * 1024 * 1024

    public static func buildPreview(from imageURL: URL) throws -> VisionAnalysisInput {
        guard let source = CGImageSourceCreateWithURL(imageURL as CFURL, nil) else {
            throw AppError.imageDecodeFailed(detail: "Failed to open image source from \(imageURL.lastPathComponent)")
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxLongEdgePixels,
            kCGImageSourceShouldCacheImmediately: true
        ]

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw AppError.imageDecodeFailed(detail: "Failed to render downsampled preview")
        }

        let width = cgImage.width
        let height = cgImage.height
        let alphaInfo = cgImage.alphaInfo
        let hasAlpha = alphaInfo == .first || alphaInfo == .last || alphaInfo == .premultipliedFirst || alphaInfo == .premultipliedLast

        var encodedData: Data? = nil
        let mimeType = "image/jpeg"

        if hasAlpha {
            encodedData = encodeJPEGWithNeutralBackground(cgImage: cgImage, quality: 0.82)
        } else {
            encodedData = encodeDirectJPEG(cgImage: cgImage, quality: 0.82)
        }

        guard var finalData = encodedData, !finalData.isEmpty else {
            throw AppError.imageDecodeFailed(detail: "Failed to compress preview image to JPEG")
        }

        if finalData.count > maxPayloadBytes {
            if let compressed = encodeDirectJPEG(cgImage: cgImage, quality: 0.5) {
                finalData = compressed
            }
        }

        let sha256Hex = (try? FileIdentityReader.computeStreamingSHA256(at: imageURL))
            .map { $0.map { String(format: "%02x", $0) }.joined() } ?? UUID().uuidString

        return VisionAnalysisInput(
            imagePreviewData: finalData,
            mimeType: mimeType,
            pixelWidth: width,
            pixelHeight: height,
            sha256Hex: sha256Hex
        )
    }

    public static func createValidTestJPEG() -> VisionAnalysisInput {
        let width = 32
        let height = 32
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return VisionAnalysisInput(imagePreviewData: Data(), mimeType: "image/jpeg", pixelWidth: 1, pixelHeight: 1, sha256Hex: "test")
        }

        context.setFillColor(CGColor(red: 0.2, green: 0.6, blue: 0.9, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))

        if let cgImage = context.makeImage(),
           let jpegData = encodeDirectJPEG(cgImage: cgImage, quality: 0.8) {
            return VisionAnalysisInput(
                imagePreviewData: jpegData,
                mimeType: "image/jpeg",
                pixelWidth: width,
                pixelHeight: height,
                sha256Hex: "test_fixture"
            )
        }

        return VisionAnalysisInput(imagePreviewData: Data(), mimeType: "image/jpeg", pixelWidth: 1, pixelHeight: 1, sha256Hex: "test")
    }

    private static func encodeDirectJPEG(cgImage: CGImage, quality: CGFloat) -> Data? {
        let mutableData = NSMutableData()
        guard let dest = CGImageDestinationCreateWithData(mutableData as CFMutableData, "public.jpeg" as CFString, 1, nil) else {
            return nil
        }
        let options: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: quality
        ]
        CGImageDestinationAddImage(dest, cgImage, options as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        return mutableData as Data
    }

    private static func encodeJPEGWithNeutralBackground(cgImage: CGImage, quality: CGFloat) -> Data? {
        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return encodeDirectJPEG(cgImage: cgImage, quality: quality)
        }

        context.setFillColor(CGColor(gray: 0.96, alpha: 1.0))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let flattened = context.makeImage() else {
            return encodeDirectJPEG(cgImage: cgImage, quality: quality)
        }
        return encodeDirectJPEG(cgImage: flattened, quality: quality)
    }
}
