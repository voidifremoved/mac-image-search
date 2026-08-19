import Foundation
import Accelerate

public actor ExactVectorIndex: VectorIndexing {
    private var analysisIDs: [Int64] = []
    private var idToIndex: [Int64: Int] = [:]
    private var matrix: [Float] = []
    private var dimension: Int = 0
    private var activeFingerprint: EmbeddingFingerprint?

    public init() {}

    public func rebuild(from records: [VectorRecord]) async throws {
        guard let first = records.first else {
            analysisIDs.removeAll()
            idToIndex.removeAll()
            matrix.removeAll()
            dimension = 0
            return
        }

        let dim = first.vector.count
        dimension = dim
        analysisIDs = []
        idToIndex = [:]
        matrix = [Float](repeating: 0, count: records.count * dim)

        for (idx, record) in records.enumerated() {
            guard record.vector.count == dim else { continue }
            analysisIDs.append(record.analysisID)
            idToIndex[record.analysisID] = idx

            let start = idx * dim
            for d in 0..<dim {
                matrix[start + d] = record.vector[d]
            }
        }
    }

    public func upsert(_ records: [VectorRecord]) async throws {
        for record in records {
            guard dimension == 0 || record.vector.count == dimension else { continue }
            if dimension == 0 {
                dimension = record.vector.count
            }

            if let existingIdx = idToIndex[record.analysisID] {
                let start = existingIdx * dimension
                for d in 0..<dimension {
                    matrix[start + d] = record.vector[d]
                }
            } else {
                let newIdx = analysisIDs.count
                analysisIDs.append(record.analysisID)
                idToIndex[record.analysisID] = newIdx
                matrix.append(contentsOf: record.vector)
            }
        }
    }

    public func remove(ids: [Int64]) async {
        let set = Set(ids)
        var newRecords: [VectorRecord] = []
        for id in analysisIDs {
            if !set.contains(id), let idx = idToIndex[id] {
                let start = idx * dimension
                let vec = Array(matrix[start..<(start + dimension)])
                newRecords.append(VectorRecord(analysisID: id, vector: vec))
            }
        }
        try? await rebuild(from: newRecords)
    }

    public func nearest(to queryVector: [Float], limit: Int) async throws -> [VectorMatch] {
        guard dimension > 0, queryVector.count == dimension, !analysisIDs.isEmpty else {
            return []
        }

        let count = analysisIDs.count
        var scores = [Float](repeating: 0, count: count)

        // Compute dot products against matrix with vDSP
        queryVector.withUnsafeBufferPointer { queryBuf in
            matrix.withUnsafeBufferPointer { matrixBuf in
                guard let qPtr = queryBuf.baseAddress, let mPtr = matrixBuf.baseAddress else { return }
                vDSP_mmul(
                    mPtr, 1,
                    qPtr, 1,
                    &scores, 1,
                    vDSP_Length(count),
                    1,
                    vDSP_Length(dimension)
                )
            }
        }

        // Collect matches
        var matches: [VectorMatch] = []
        matches.reserveCapacity(count)
        for i in 0..<count {
            matches.append(VectorMatch(analysisID: analysisIDs[i], score: scores[i]))
        }

        // Sort descending by score
        matches.sort { $0.score > $1.score }
        if matches.count > limit {
            return Array(matches.prefix(limit))
        }
        return matches
    }

    public func count() -> Int {
        analysisIDs.count
    }
}
