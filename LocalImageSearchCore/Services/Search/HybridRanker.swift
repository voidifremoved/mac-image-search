import Foundation

public enum HybridRanker {
    public static let kConstant: Float = 60.0
    public static let semanticWeight: Float = 1.0
    public static let lexicalWeight: Float = 0.65
    public static let filenameBoostWeight: Float = 0.15

    public struct ScoredCandidate: Sendable {
        public let analysisID: Int64
        public var rrfScore: Float
        public var semanticScore: Float
        public var lexicalScore: Float
    }

    public static func fuse(
        semanticMatches: [VectorMatch],
        lexicalMatches: [SearchRepository.FTSMatch],
        query: String,
        candidateDetails: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)]
    ) -> [ScoredCandidate] {
        var scores: [Int64: ScoredCandidate] = [:]
        let normalizedQuery = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Semantic RRF
        for (rank, match) in semanticMatches.enumerated() {
            let rrf = semanticWeight / (kConstant + Float(rank + 1))
            if var existing = scores[match.analysisID] {
                existing.rrfScore += rrf
                existing.semanticScore = match.score
                scores[match.analysisID] = existing
            } else {
                scores[match.analysisID] = ScoredCandidate(
                    analysisID: match.analysisID,
                    rrfScore: rrf,
                    semanticScore: match.score,
                    lexicalScore: 0
                )
            }
        }

        // 2. Lexical RRF
        for (rank, match) in lexicalMatches.enumerated() {
            let rrf = lexicalWeight / (kConstant + Float(rank + 1))
            if var existing = scores[match.analysisID] {
                existing.rrfScore += rrf
                existing.lexicalScore = Float(match.rank)
                scores[match.analysisID] = existing
            } else {
                scores[match.analysisID] = ScoredCandidate(
                    analysisID: match.analysisID,
                    rrfScore: rrf,
                    semanticScore: 0,
                    lexicalScore: Float(match.rank)
                )
            }
        }

        // 3. Filename exact match boost
        if !normalizedQuery.isEmpty {
            for (id, tuple) in candidateDetails {
                let filename = (tuple.asset.relativePath as NSString).lastPathComponent.lowercased()
                if filename.contains(normalizedQuery) {
                    if var existing = scores[id] {
                        existing.rrfScore += filenameBoostWeight
                        scores[id] = existing
                    }
                }
            }
        }

        var results = Array(scores.values)
        results.sort { $0.rrfScore > $1.rrfScore }
        return results
    }
}
