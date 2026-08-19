import Testing
import Foundation
@testable import LocalImageSearchCore

@Suite("AI Provider & Vision Analysis Tests")
struct AITests {
    @Test("OpenRouter uses the preferred Gemini model by default")
    func testDefaultOpenRouterModel() {
        #expect(AIProviderConfiguration().model == "google/gemini-3.7-flash")
    }

    @Test("Keychain store saves, reads, and deletes API secrets")
    func testKeychainStore() throws {
        let store = InMemorySecretStore()
        let key = "test_openrouter_key"
        let secret = "sk-or-v1-abcdef123456"

        try store.setSecret(secret, forKey: key)
        let retrieved = try store.getSecret(forKey: key)
        #expect(retrieved == secret)

        try store.deleteSecret(forKey: key)
        let afterDelete = try store.getSecret(forKey: key)
        #expect(afterDelete == nil)
    }

    @Test("AI Provider configuration validates HTTPS URLs and localhost exception")
    func testProviderURLValidation() throws {
        var config = AIProviderConfiguration(baseURLString: "http://insecure-remote.ai/api")
        #expect(throws: AppError.self) {
            _ = try config.validatedBaseURL()
        }

        // Localhost allowed with HTTP
        config.baseURLString = "http://localhost:11434/v1"
        let localURL = try config.validatedBaseURL()
        #expect(localURL.host == "localhost")

        // HTTPS allowed
        config.baseURLString = "https://openrouter.ai/api/v1"
        let httpsURL = try config.validatedBaseURL()
        #expect(httpsURL.scheme == "https")
    }

    @Test("Parsing valid JSON and fenced JSON fallbacks")
    func testFencedJSONParsing() throws {
        let store = InMemorySecretStore()
        let config = AIProviderConfiguration()
        let client = OpenAICompatibleVisionClient(configuration: config, secretStore: store)

        let fencedJSON = """
        Here is the analysis:
        ```json
        {
          "short_title": "Red Sports Car on Mountain Road",
          "description": "A vibrant red convertible drives along a winding alpine road during daylight.",
          "categories": ["vehicles", "automotive", "mountains"],
          "objects": ["car", "road", "mountains", "trees"],
          "scene": "mountain pass",
          "dominant_colors": ["red", "gray", "green"],
          "visible_text": "SPEED LIMIT 45",
          "people_count": 1,
          "time_of_day": "day",
          "search_keywords": ["convertible", "highway", "scenic"]
        }
        ```
        Hope that helps!
        """

        let parsed = try client.parseAnalysisContent(fencedJSON)
        #expect(parsed.shortTitle == "Red Sports Car on Mountain Road")
        #expect(parsed.categories.contains("vehicles"))
        #expect(parsed.dominantColors.contains("red"))
        #expect(parsed.peopleCount == 1)

        let searchableText = parsed.buildSearchableText()
        #expect(searchableText.contains("SPEED LIMIT 45"))
        #expect(searchableText.contains("Red Sports Car"))
    }

    @Test("Version 2 analysis keeps summary and complete text separate")
    func testSummaryAndFullTextParsing() throws {
        let client = OpenAICompatibleVisionClient(
            configuration: AIProviderConfiguration(),
            secretStore: InMemorySecretStore()
        )
        let fullText = String(repeating: "Invoice line item 123 — £45.00\n", count: 180)
        let payload: [String: Any] = [
            "short_title": "Detailed Invoice Screenshot",
            "summary": "A screenshot of a multi-line invoice with itemized charges.",
            "categories": ["documents", "finance"],
            "objects": ["invoice", "table"],
            "scene": NSNull(),
            "dominant_colors": ["white", "black"],
            "full_text": fullText,
            "people_count": 0,
            "time_of_day": "unknown",
            "search_keywords": ["receipt", "billing"]
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let parsed = try client.parseAnalysisContent(String(decoding: data, as: UTF8.self))

        #expect(parsed.description == "A screenshot of a multi-line invoice with itemized charges.")
        #expect(parsed.visibleText == fullText)
        #expect(parsed.visibleText!.count > 4_000)
        #expect(parsed.buildSearchableText().contains("Invoice line item 123"))
    }
}
