import Position
import Ranking

public struct SearchHit<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let documentID: ID
    public let score: RankingScore
    public let evidence: [SearchEvidence]

    public init(
        documentID: ID,
        score: RankingScore,
        evidence: [SearchEvidence]
    ) {
        self.documentID = documentID
        self.score = score
        self.evidence = evidence
    }

    public var ranges: [PositionRange] {
        evidence.flatMap {
            $0.spans.map(\.range)
        }
    }

    public var lineRanges: [LineRange] {
        evidence.flatMap {
            $0.spans.map(\.lineRange)
        }
    }
}

extension SearchHit: Codable where ID: Codable {}
