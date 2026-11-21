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
    /// Match only this field of a candidate; every field when nil.
    public let field: String?

    public init(
        _ query: SearchQuery,
        role: SearchProbeRole = .preferred,
        strategy: SearchStrategy = .fuzzy,
        field: String? = nil
    ) {
        self.query = query
        self.role = role
        self.strategy = strategy
        self.field = field
    }

    public init(
        _ text: String,
        id: String? = nil,
        weight: Int = 1,
        role: SearchProbeRole = .preferred,
        strategy: SearchStrategy = .fuzzy,
        field: String? = nil
    ) {
        self.init(
            SearchQuery(
                text,
                id: id,
                weight: weight
            ),
            role: role,
            strategy: strategy,
            field: field
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
