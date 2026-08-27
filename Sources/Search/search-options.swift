import Matching

public typealias SearchStrategy = MatchStrategy

public struct SearchOptions:
    Sendable,
    Codable,
    Hashable
{
    public var strategy: SearchStrategy
    public var caseSensitive: Bool
    public var minimumScore: Int?
    public var maximumResults: Int?

    public init(
        strategy: SearchStrategy = .fuzzy,
        caseSensitive: Bool = false,
        minimumScore: Int? = 1,
        maximumResults: Int? = 8
    ) {
        self.strategy = strategy
        self.caseSensitive = caseSensitive
        self.minimumScore = minimumScore
        self.maximumResults = maximumResults.map {
            max(
                0,
                $0
            )
        }
    }

    public static let defaults: Self = .init()
}
