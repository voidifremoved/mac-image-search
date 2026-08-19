import Foundation

public enum ErrorSubsystem: String, Sendable, Codable {
    case folder
    case file
    case image
    case provider
    case embedding
    case database
    case security
    case system
}

public enum RetryClassification: String, Sendable, Codable {
    case nonRetryable
    case retryableImmediate
    case retryableWithBackoff
    case requiresUserAction
}

public enum ErrorPrivacyLevel: String, Sendable, Codable {
    case `public`
    case redacted
    case privateOnly
}

public struct AppError: Error, Sendable, Codable, LocalizedError, CustomStringConvertible {
    public let subsystem: ErrorSubsystem
    public let code: String
    public let userMessage: String
    public let recoverySuggestion: String?
    public let retryClassification: RetryClassification
    public let underlyingDetail: String?
    public let privacyLevel: ErrorPrivacyLevel
    public let timestamp: Date

    public init(
        subsystem: ErrorSubsystem,
        code: String,
        userMessage: String,
        recoverySuggestion: String? = nil,
        retryClassification: RetryClassification = .nonRetryable,
        underlyingDetail: String? = nil,
        privacyLevel: ErrorPrivacyLevel = .public,
        timestamp: Date = Date()
    ) {
        self.subsystem = subsystem
        self.code = code
        self.userMessage = userMessage
        self.recoverySuggestion = recoverySuggestion
        self.retryClassification = retryClassification
        self.underlyingDetail = underlyingDetail
        self.privacyLevel = privacyLevel
        self.timestamp = timestamp
    }

    public var errorDescription: String? {
        userMessage
    }

    public var description: String {
        "[\(subsystem.rawValue).\(code)] \(userMessage)" + (underlyingDetail.map { " (\($0))" } ?? "")
    }

    // Common Factory Methods
    public static func folderBookmarkStale(path: String) -> AppError {
        AppError(
            subsystem: .folder,
            code: "bookmark_stale",
            userMessage: "Folder security bookmark needs to be renewed.",
            recoverySuggestion: "Re-select the folder in Settings or Library.",
            retryClassification: .requiresUserAction
        )
    }

    public static func folderPermissionDenied(path: String) -> AppError {
        AppError(
            subsystem: .folder,
            code: "permission_denied",
            userMessage: "Permission to access folder was denied.",
            recoverySuggestion: "Grant folder access in System Settings > Privacy & Security > Files and Folders.",
            retryClassification: .requiresUserAction
        )
    }

    public static func folderVolumeOffline(path: String) -> AppError {
        AppError(
            subsystem: .folder,
            code: "volume_offline",
            userMessage: "Folder volume is currently offline or disconnected.",
            recoverySuggestion: "Reconnect the external drive or network share.",
            retryClassification: .requiresUserAction
        )
    }

    public static func fileUnstable(path: String) -> AppError {
        AppError(
            subsystem: .file,
            code: "unstable",
            userMessage: "File is currently being written or modified.",
            retryClassification: .retryableWithBackoff
        )
    }

    public static func imageDecodeFailed(detail: String) -> AppError {
        AppError(
            subsystem: .image,
            code: "decode_failed",
            userMessage: "Unable to decode image format or dimensions.",
            retryClassification: .nonRetryable,
            underlyingDetail: detail
        )
    }

    public static func providerUnauthorized(detail: String) -> AppError {
        AppError(
            subsystem: .provider,
            code: "unauthorized",
            userMessage: "AI Provider API key is invalid or expired.",
            recoverySuggestion: "Update your API key in Settings > AI Provider.",
            retryClassification: .requiresUserAction,
            underlyingDetail: detail
        )
    }

    public static func providerRateLimited(retryAfter: TimeInterval?) -> AppError {
        AppError(
            subsystem: .provider,
            code: "rate_limited",
            userMessage: "AI Provider rate limit exceeded.",
            recoverySuggestion: "Requests will automatically resume with backoff.",
            retryClassification: .retryableWithBackoff,
            underlyingDetail: retryAfter.map { "Retry-After: \($0)s" }
        )
    }

    public static func providerModelNotVisionCapable(model: String) -> AppError {
        AppError(
            subsystem: .provider,
            code: "model_not_vision_capable",
            userMessage: "Selected AI model does not support image analysis.",
            recoverySuggestion: "Select a vision-capable model in Settings.",
            retryClassification: .requiresUserAction,
            underlyingDetail: model
        )
    }

    public static func providerInvalidResponse(detail: String) -> AppError {
        AppError(
            subsystem: .provider,
            code: "invalid_response",
            userMessage: "AI Provider returned an invalid or malformed response.",
            retryClassification: .retryableWithBackoff,
            underlyingDetail: detail
        )
    }

    public static func embeddingUnavailable(detail: String) -> AppError {
        AppError(
            subsystem: .embedding,
            code: "unavailable",
            userMessage: "Local sentence embedding model is unavailable.",
            recoverySuggestion: "Verify English language assets are installed or configure remote embeddings.",
            retryClassification: .requiresUserAction,
            underlyingDetail: detail
        )
    }

    public static func databaseCorrupt(detail: String) -> AppError {
        AppError(
            subsystem: .database,
            code: "corrupt",
            userMessage: "Database integrity check failed.",
            recoverySuggestion: "Export diagnostics and rebuild the index in Settings.",
            retryClassification: .requiresUserAction,
            underlyingDetail: detail
        )
    }
}
