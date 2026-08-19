import Foundation

public final class OpenAICompatibleVisionClient: VisionAnalyzer, Sendable {
    private let configuration: AIProviderConfiguration
    private let secretStore: SecretStoring
    private let urlSession: URLSession

    public init(
        configuration: AIProviderConfiguration,
        secretStore: SecretStoring,
        urlSession: URLSession = URLSession(configuration: .ephemeral)
    ) {
        self.configuration = configuration
        self.secretStore = secretStore
        self.urlSession = urlSession
    }

    public func analyze(_ input: VisionAnalysisInput) async throws -> AnalysisResponse {
        let apiKey = try secretStore.getSecret(forKey: configuration.apiKeyIdentifier) ?? ""
        if apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.providerUnauthorized(detail: "API key is missing.")
        }

        let baseURL = try configuration.validatedBaseURL()
        let chatURL = baseURL.appendingPathComponent(configuration.chatPath.trimmingCharacters(in: CharacterSet(charactersIn: "/")))

        var request = URLRequest(url: chatURL)
        request.httpMethod = "POST"
        request.timeoutInterval = configuration.requestTimeout
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (k, v) in configuration.extraHeaders {
            let lower = k.lowercased()
            if lower != "authorization" && lower != "host" && lower != "content-length" {
                request.setValue(v, forHTTPHeaderField: k)
            }
        }

        let base64Image = input.imagePreviewData.base64EncodedString()
        let dataURL = "data:\(input.mimeType);base64,\(base64Image)"

        let requestBody: [String: Any] = [
            "model": configuration.model,
            "temperature": 0,
            "max_tokens": 1000,
            "messages": [
                [
                    "role": "system",
                    "content": AnalysisPrompt.systemPrompt
                ],
                [
                    "role": "user",
                    "content": [
                        [
                            "type": "text",
                            "text": "Analyze this image and return the structured JSON object."
                        ],
                        [
                            "type": "image_url",
                            "image_url": [
                                "url": dataURL
                            ]
                        ]
                    ]
                ]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        return try await executeWithBackoff(request: request, repairAttempt: true)
    }

    private func executeWithBackoff(request: URLRequest, repairAttempt: Bool) async throws -> AnalysisResponse {
        let backoffSchedule: [TimeInterval] = [2.0, 5.0, 15.0]

        for attempt in 0...backoffSchedule.count {
            if Task.isCancelled {
                throw CancellationError()
            }

            do {
                let (data, response) = try await urlSession.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    throw AppError.providerInvalidResponse(detail: "Non-HTTP response received")
                }

                if httpResponse.statusCode == 200 {
                    return try parseResponse(data: data)
                }

                // Extract server error details
                var serverDetail: String = "HTTP \(httpResponse.statusCode)"
                if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                    if let errorDict = json["error"] as? [String: Any], let msg = errorDict["message"] as? String {
                        serverDetail = msg
                    } else if let errorMsg = json["message"] as? String {
                        serverDetail = errorMsg
                    }
                } else if let rawString = String(data: data, encoding: .utf8), !rawString.isEmpty {
                    serverDetail = rawString
                }

                if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
                    throw AppError.providerUnauthorized(detail: serverDetail)
                }

                if httpResponse.statusCode == 400 || httpResponse.statusCode == 404 {
                    throw AppError(
                        subsystem: .provider,
                        code: "request_failed",
                        userMessage: "Provider error (\(httpResponse.statusCode)): \(serverDetail)"
                    )
                }

                if httpResponse.statusCode == 429 || httpResponse.statusCode >= 500 {
                    if attempt < backoffSchedule.count {
                        var delay = backoffSchedule[attempt]
                        if let retryAfterStr = httpResponse.value(forHTTPHeaderField: "Retry-After"),
                           let retryAfterSec = Double(retryAfterStr) {
                            delay = retryAfterSec
                        }
                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw AppError.providerRateLimited(retryAfter: nil)
                    }
                }

                throw AppError.providerInvalidResponse(detail: serverDetail)
            } catch let appErr as AppError {
                throw appErr
            } catch {
                if attempt < backoffSchedule.count {
                    let delay = backoffSchedule[attempt]
                    try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                    continue
                }
                throw AppError.providerInvalidResponse(detail: error.localizedDescription)
            }
        }

        throw AppError.providerInvalidResponse(detail: "Exhausted retries")
    }

    public func parseResponse(data: Data) throws -> AnalysisResponse {
        guard let jsonObject = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = jsonObject["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let contentString = message["content"] as? String else {
            throw AppError.providerInvalidResponse(detail: "Unable to parse chat completion structure")
        }

        return try parseAnalysisContent(contentString)
    }

    public func parseAnalysisContent(_ rawText: String) throws -> AnalysisResponse {
        var cleanJSON = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        if cleanJSON.contains("```json") {
            if let start = cleanJSON.range(of: "```json")?.upperBound,
               let end = cleanJSON[start...].range(of: "```")?.lowerBound {
                cleanJSON = String(cleanJSON[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else if cleanJSON.contains("```") {
            if let start = cleanJSON.range(of: "```")?.upperBound,
               let end = cleanJSON[start...].range(of: "```")?.lowerBound {
                cleanJSON = String(cleanJSON[start..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        guard let jsonData = cleanJSON.data(using: .utf8) else {
            throw AppError.providerInvalidResponse(detail: "Failed to read UTF-8 JSON content")
        }

        let decoder = JSONDecoder()
        do {
            let decoded = try decoder.decode(AnalysisResponse.self, from: jsonData)
            return sanitize(decoded)
        } catch {
            throw AppError.providerInvalidResponse(detail: "JSON Schema decode failed: \(error.localizedDescription)")
        }
    }

    private func sanitize(_ response: AnalysisResponse) -> AnalysisResponse {
        let maxArrLen = 20
        let maxItemLen = 80

        let cleanCategories = Array(response.categories
            .map { String($0.prefix(maxItemLen)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxArrLen))

        let cleanObjects = Array(response.objects
            .map { String($0.prefix(maxItemLen)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxArrLen))

        let cleanColors = Array(response.dominantColors
            .map { String($0.prefix(maxItemLen)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxArrLen))

        let cleanKeywords = Array(response.searchKeywords
            .map { String($0.prefix(maxItemLen)).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(maxArrLen))

        let cleanDesc = String(response.description.prefix(2000))
        let cleanText = response.visibleText.map { String($0.prefix(4000)) }

        return AnalysisResponse(
            shortTitle: String(response.shortTitle.prefix(120)),
            description: cleanDesc,
            categories: cleanCategories,
            objects: cleanObjects,
            scene: response.scene.map { String($0.prefix(100)) },
            dominantColors: cleanColors,
            visibleText: cleanText,
            peopleCount: response.peopleCount.map { max(0, min($0, 1000)) },
            timeOfDay: response.timeOfDay,
            searchKeywords: cleanKeywords
        )
    }
}
