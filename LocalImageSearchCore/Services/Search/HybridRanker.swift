import Foundation

public enum HybridRanker {
    public struct ScoredCandidate: Sendable {
        public let analysisID: Int64
        public var rrfScore: Float
        public var semanticScore: Float
        public var lexicalScore: Float
        public var hasLexicalEvidence: Bool
    }

    /// Combines vector similarity with deterministic matching across the fields users can see.
    /// Low-similarity vector neighbors are deliberately removed: a nearest neighbor is not
    /// necessarily a relevant result, especially in a small library.
    public static func fuse(
        semanticMatches: [VectorMatch],
        lexicalMatches: [SearchRepository.FTSMatch],
        query: String,
        candidateDetails: [Int64: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)]
    ) -> [ScoredCandidate] {
        let tokens = meaningfulTokens(query)
        guard !tokens.isEmpty else { return [] }

        let semanticByID = Dictionary(uniqueKeysWithValues: semanticMatches.map { ($0.analysisID, $0.score) })
        let lexicalRankByID = Dictionary(uniqueKeysWithValues: lexicalMatches.enumerated().map { ($0.element.analysisID, $0.offset) })
        let bestSemantic = semanticMatches.map(\.score).max() ?? -1
        // Vector indexes always have a nearest neighbor, even when nothing is relevant.
        // Keep a narrow band near a credible best match; explicit lexical/category
        // evidence remains eligible independently of this semantic threshold.
        let hasAnyLexicalMatches = !lexicalMatches.isEmpty
        let minimumUsefulSemantic: Float = hasAnyLexicalMatches ? 0.45 : 0.32
        let relativeSemanticWindow: Float = hasAnyLexicalMatches ? 0.05 : 0.08
        let semanticIsUseful = bestSemantic >= minimumUsefulSemantic
        let semanticFloor = max(minimumUsefulSemantic, bestSemantic - relativeSemanticWindow)

        var results: [ScoredCandidate] = []
        results.reserveCapacity(candidateDetails.count)

        for (analysisID, details) in candidateDetails {
            let rawSemantic = semanticByID[analysisID] ?? -1
            let passesSemanticCutoff = semanticIsUseful && rawSemantic >= semanticFloor
            let fieldScore = metadataRelevance(query: query, tokens: tokens, details: details)
            let lexicalRank = lexicalRankByID[analysisID]
            let hasLexicalEvidence = lexicalRank != nil || fieldScore > 0

            guard passesSemanticCutoff || hasLexicalEvidence else { continue }

            let semanticRelevance: Float
            if passesSemanticCutoff {
                let range = max(0.0001, bestSemantic - semanticFloor)
                semanticRelevance = 0.35 + (0.65 * min(1, max(0, (rawSemantic - semanticFloor) / range)))
            } else {
                semanticRelevance = 0
            }

            let rankedLexical: Float
            if let lexicalRank {
                rankedLexical = 1 / (1 + Float(lexicalRank) * 0.12)
            } else {
                rankedLexical = 0
            }

            // Exact/visible metadata evidence should beat a vaguely related vector result.
            let evidenceBonus: Float = hasLexicalEvidence ? 0.12 : 0
            let combined = semanticRelevance * 0.48 + fieldScore * 0.42 + rankedLexical * 0.10 + evidenceBonus
            let minimumScore: Float = hasLexicalEvidence ? 0.08 : 0.34
            guard combined >= minimumScore else { continue }
            results.append(ScoredCandidate(
                analysisID: analysisID,
                rrfScore: combined,
                semanticScore: rawSemantic == -1 ? 0 : rawSemantic,
                lexicalScore: fieldScore,
                hasLexicalEvidence: hasLexicalEvidence
            ))
        }

        let sorted = results.sorted {
            if $0.rrfScore == $1.rrfScore { return $0.analysisID < $1.analysisID }
            return $0.rrfScore > $1.rrfScore
        }
        let semanticOnlyLimit = hasAnyLexicalMatches ? 5 : 16
        var semanticOnlyCount = 0
        return sorted.filter { candidate in
            if candidate.hasLexicalEvidence { return true }
            guard semanticOnlyCount < semanticOnlyLimit else { return false }
            semanticOnlyCount += 1
            return true
        }
    }

    private static func metadataRelevance(
        query: String,
        tokens: [String],
        details: (asset: ImageAsset, content: ImageContent, analysis: ImageAnalysis)
    ) -> Float {
        let analysis = details.analysis
        let fields: [(String, Float)] = [
            (analysis.shortTitle, 1.0),
            (analysis.categories.joined(separator: " "), 0.95),
            (analysis.objects.joined(separator: " "), 0.9),
            (analysis.scene ?? "", 0.85),
            (analysis.description, 0.78),
            (analysis.visibleText ?? "", 0.82),
            ((details.asset.relativePath as NSString).lastPathComponent, 1.0)
        ]

        let normalizedQuery = normalized(query)
        var best: Float = 0
        for (field, weight) in fields where !field.isEmpty {
            let normalizedField = normalized(field)
            let fieldWords = Set(normalizedField.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty })
            let matched = tokens.filter { token in
                fieldWords.contains(where: { word in word == token || word.hasPrefix(token) || token.hasPrefix(word) })
            }.count
            guard matched > 0 else { continue }
            var score = Float(matched) / Float(tokens.count)
            if normalizedQuery.count >= 3 && normalizedField.contains(normalizedQuery) {
                score = min(1, score + 0.3)
            }
            best = max(best, score * weight)
        }
        return best
    }

    private static func meaningfulTokens(_ value: String) -> [String] {
        let stopWords: Set<String> = ["a", "an", "and", "are", "at", "for", "in", "is", "of", "on", "the", "to", "with"]
        return normalized(value)
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty && !stopWords.contains($0) }
    }

    private static func normalized(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
    }
}
