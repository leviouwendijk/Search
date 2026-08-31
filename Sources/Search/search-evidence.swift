import Ranking

public struct SearchEvidence:
    Sendable,
    Codable,
    Hashable
{
    public let queryID: String?
    public let query: String
    public let role: SearchProbeRole
    public let strategy: SearchStrategy
    public let score: RankingScore
    public let spans: [SearchSpan]

    public init(
        queryID: String? = nil,
        query: String,
        role: SearchProbeRole = .preferred,
        strategy: SearchStrategy,
        score: RankingScore,
        spans: [SearchSpan]
    ) {
        self.queryID = queryID
        self.query = query
        self.role = role
        self.strategy = strategy
        self.score = score
        self.spans = spans
    }
}
