import Foundation

public struct VisionAnalysisInput: Sendable {
    public let imagePreviewData: Data
    public let mimeType: String
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let sha256Hex: String

    public init(
        imagePreviewData: Data,
        mimeType: String,
        pixelWidth: Int,
        pixelHeight: Int,
        sha256Hex: String
    ) {
        self.imagePreviewData = imagePreviewData
        self.mimeType = mimeType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.sha256Hex = sha256Hex
    }
}
