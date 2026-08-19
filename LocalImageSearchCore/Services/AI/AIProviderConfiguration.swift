import Foundation
import CryptoKit

public enum ProviderPreset: String, Sendable, Codable {
    case openRouter
    case customOpenAICompatible
}

public struct AIProviderConfiguration: Sendable, Codable, Equatable {
    public var preset: ProviderPreset
    public var baseURLString: String
    public var chatPath: String
    public var model: String
    public var apiKeyIdentifier: String
    public var extraHeaders: [String: String]
    public var requestTimeout: TimeInterval
    public var maxParallelRequests: Int

    public static let defaultAPIKeyIdentifier = "default_ai_provider_key"
    public static let defaultOpenRouterBaseURL = "https://openrouter.ai/api/v1"
    public static let defaultChatPath = "/chat/completions"
    public static let defaultOpenRouterModel = "google/gemini-3.7-flash"
    private static let userDefaultsKey = "saved_ai_provider_configuration"

    public init(
        preset: ProviderPreset = .openRouter,
        baseURLString: String = defaultOpenRouterBaseURL,
        chatPath: String = defaultChatPath,
        model: String = defaultOpenRouterModel,
        apiKeyIdentifier: String = defaultAPIKeyIdentifier,
        extraHeaders: [String: String] = [:],
        requestTimeout: TimeInterval = 90,
        maxParallelRequests: Int = 2
    ) {
        self.preset = preset
        self.baseURLString = baseURLString
        self.chatPath = chatPath
        self.model = model
        self.apiKeyIdentifier = apiKeyIdentifier
        self.extraHeaders = extraHeaders
        self.requestTimeout = requestTimeout
        self.maxParallelRequests = max(1, min(maxParallelRequests, 4))
    }

    public static func loadFromUserDefaults() -> AIProviderConfiguration {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let decoded = try? JSONDecoder().decode(AIProviderConfiguration.self, from: data) {
            return decoded
        }
        return AIProviderConfiguration()
    }

    public func saveToUserDefaults() {
        if let encoded = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(encoded, forKey: Self.userDefaultsKey)
        }
    }

    public func validatedBaseURL() throws -> URL {
        guard let url = URL(string: baseURLString), let host = url.host?.lowercased() else {
            throw AppError(
                subsystem: .provider,
                code: "invalid_url",
                userMessage: "Invalid AI Provider base URL."
            )
        }

        let isLocalhost = host == "localhost" || host == "127.0.0.1" || host == "::1"
        if !isLocalhost && url.scheme?.lowercased() != "https" {
            throw AppError(
                subsystem: .provider,
                code: "insecure_url",
                userMessage: "Remote AI provider base URL must use HTTPS for security."
            )
        }

        return url
    }

    public var configurationFingerprint: String {
        let normalized = (baseURLString + ":" + model).lowercased()
        let digest = SHA256.hash(data: normalized.data(using: .utf8) ?? Data())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
