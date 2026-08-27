import Position
import Ranking

public struct SearchCandidate<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let documentID: ID
    public let lineRange: LineRange
    public let score: RankingScore
    public let evidence: [SearchEvidence]

    public init(
        documentID: ID,
        lineRange: LineRange,
        score: RankingScore,
        evidence: [SearchEvidence]
    ) {
        self.documentID = documentID
        self.lineRange = lineRange
        self.score = score
        self.evidence = evidence
    }

    public var probeCount: Int {
        evidence.count
    }

    public var spans: [SearchSpan] {
        evidence.flatMap(\.spans)
    }
}

extension SearchCandidate: Codable where ID: Codable {}
