import Foundation

public struct RetryPolicy: Sendable {
    public static let maxAttempts = 5
    public static let baseDelays: [TimeInterval] = [2.0, 5.0, 15.0, 45.0, 120.0]

    public static func nextAttemptDelay(attemptCount: Int, retryAfter: TimeInterval? = nil) -> TimeInterval? {
        if attemptCount >= maxAttempts {
            return nil
        }
        if let retryAfter, retryAfter > 0 {
            return retryAfter
        }
        let index = min(attemptCount, baseDelays.count - 1)
        let base = baseDelays[index]
        // Full jitter between base * 0.8 and base * 1.2
        let jitter = Double.random(in: 0.8...1.2)
        return base * jitter
    }
}
