import Matching

public typealias SearchStrategy = MatchStrategy

public enum SearchMode:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case ranked
    case exhaustive
}

public struct SearchOptions:
    Sendable,
    Codable,
    Hashable
{
    public var mode: SearchMode
    public var strategy: SearchStrategy
    public var caseSensitive: Bool
    public var minimumScore: Int?
    public var maximumResults: Int?

    public init(
        mode: SearchMode = .ranked,
        strategy: SearchStrategy = .fuzzy,
        caseSensitive: Bool = false,
        minimumScore: Int? = 1,
        maximumResults: Int? = 8
    ) {
        self.mode = mode
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
