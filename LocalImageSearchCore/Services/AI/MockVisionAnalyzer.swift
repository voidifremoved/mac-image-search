import Foundation

public final class MockVisionAnalyzer: VisionAnalyzer, @unchecked Sendable {
    public var stubbedResponse: AnalysisResponse?
    public var errorToThrow: Error?
    public var analyzeCallCount = 0

    public init(stubbedResponse: AnalysisResponse? = nil) {
        self.stubbedResponse = stubbedResponse
    }

    public func analyze(_ input: VisionAnalysisInput) async throws -> AnalysisResponse {
        analyzeCallCount += 1
        if let errorToThrow {
            throw errorToThrow
        }
        if let stubbedResponse {
            return stubbedResponse
        }
        return AnalysisResponse(
            shortTitle: "Test Mock Image",
            description: "A simulated mock image preview description for testing.",
            categories: ["test", "mock"],
            objects: ["preview", "canvas"],
            scene: "studio",
            dominantColors: ["blue", "white"],
            visibleText: "MOCK TEXT",
            searchKeywords: ["synthetic", "test"]
        )
    }
}
