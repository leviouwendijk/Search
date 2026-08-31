import Matching

public enum SearchProbeRole:
    String,
    Sendable,
    Codable,
    Hashable,
    CaseIterable
{
    case required
    case preferred
    case excluded
}

public struct SearchProbe:
    Sendable,
    Codable,
    Hashable
{
    public let query: SearchQuery
    public let role: SearchProbeRole
    public let strategy: SearchStrategy

    public init(
        _ query: SearchQuery,
        role: SearchProbeRole = .preferred,
        strategy: SearchStrategy = .fuzzy
    ) {
        self.query = query
        self.role = role
        self.strategy = strategy
    }

    public init(
        _ text: String,
        id: String? = nil,
        weight: Int = 1,
        role: SearchProbeRole = .preferred,
        strategy: SearchStrategy = .fuzzy
    ) {
        self.init(
            SearchQuery(
                text,
                id: id,
                weight: weight
            ),
            role: role,
            strategy: strategy
        )
    }

    public var id: String? {
        query.id
    }

    public var text: String {
        query.text
    }

    public var weight: Int {
        query.weight
    }

    public var isEmpty: Bool {
        query.isEmpty
    }
}
