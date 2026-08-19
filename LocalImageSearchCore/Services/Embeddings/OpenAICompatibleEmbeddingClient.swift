import Foundation

public final class OpenAICompatibleEmbeddingClient: EmbeddingService, Sendable {
    private let baseURL: URL
    private let model: String
    private let secretStore: SecretStoring
    private let apiKeyIdentifier: String
    private let urlSession: URLSession
    private let configuredDimension: Int

    public init(
        baseURL: URL,
        model: String = "text-embedding-3-small",
        secretStore: SecretStoring,
        apiKeyIdentifier: String,
        dimension: Int = 1536,
        urlSession: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.baseURL = baseURL
        self.model = model
        self.secretStore = secretStore
        self.apiKeyIdentifier = apiKeyIdentifier
        self.configuredDimension = dimension
        self.urlSession = urlSession
    }

    public var fingerprint: EmbeddingFingerprint {
        get async throws {
            EmbeddingFingerprint(
                engineKind: "openAICompatible",
                model: model,
                revision: "1",
                dimension: configuredDimension
            )
        }
    }

    public func embed(_ texts: [String]) async throws -> [[Float]] {
        guard !texts.isEmpty else { return [] }

        let apiKey = try secretStore.getSecret(forKey: apiKeyIdentifier) ?? ""
        let endpoint = baseURL.appendingPathComponent("embeddings")

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": model,
            "input": texts
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, response) = try await urlSession.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 else {
            throw AppError.providerInvalidResponse(detail: "Embedding API error")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw AppError.providerInvalidResponse(detail: "Failed to parse embeddings response")
        }

        var results: [[Float]] = []
        for item in dataArray {
            if let emb = item["embedding"] as? [Double] {
                let floatVec = AppleSentenceEmbeddingService.normalize(vector: emb.map { Float($0) })
                results.append(floatVec)
            }
        }

        return results
    }
}
