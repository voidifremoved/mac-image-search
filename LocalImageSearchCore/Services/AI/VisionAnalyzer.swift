import Foundation

public protocol VisionAnalyzer: Sendable {
    func analyze(_ input: VisionAnalysisInput) async throws -> AnalysisResponse
}
