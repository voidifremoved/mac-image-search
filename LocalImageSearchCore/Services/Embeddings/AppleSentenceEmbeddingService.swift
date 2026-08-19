import Foundation
@preconcurrency import NaturalLanguage
import Accelerate

public actor AppleSentenceEmbeddingService: EmbeddingService {
    private let embedding: NLEmbedding?

    public init() {
        self.embedding = NLEmbedding.sentenceEmbedding(for: .english)
    }

    public var fingerprint: EmbeddingFingerprint {
        get throws {
            guard let embedding else {
                throw AppError.embeddingUnavailable(detail: "Apple English sentence embedding is not available on this system.")
            }
            let dimension = embedding.dimension
            let revision = embedding.revision
            return EmbeddingFingerprint(
                engineKind: "appleSentence",
                model: "sentence-embedding-en",
                revision: "\(revision)",
                dimension: dimension
            )
        }
    }

    public func embed(_ texts: [String]) throws -> [[Float]] {
        guard let embedding else {
            throw AppError.embeddingUnavailable(detail: "Apple English sentence embedding is not available on this system.")
        }

        var results: [[Float]] = []
        for text in texts {
            guard let doubleVector = embedding.vector(for: text) else {
                results.append(Array(repeating: 0.0, count: embedding.dimension))
                continue
            }

            var floatVector = doubleVector.map { Float($0) }
            floatVector = Self.normalize(vector: floatVector)
            results.append(floatVector)
        }

        return results
    }

    public static func normalize(vector: [Float]) -> [Float] {
        var norm: Float = 0
        vDSP_svesq(vector, 1, &norm, vDSP_Length(vector.count))
        let length = sqrt(norm)
        if length > 1e-8 {
            var divisor = length
            var normalized = [Float](repeating: 0, count: vector.count)
            vDSP_vsdiv(vector, 1, &divisor, &normalized, 1, vDSP_Length(vector.count))
            return normalized
        }
        return vector
    }
}
