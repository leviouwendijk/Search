public struct SearchRequest:
    Sendable,
    Codable,
    Hashable
{
    public let probes: [SearchProbe]
    public let options: SearchOptions

    public var queries: [SearchQuery] {
        probes.map(\.query)
    }

    public init(
        probes: [SearchProbe],
        options: SearchOptions = .defaults
    ) {
        self.probes = probes
        self.options = options
    }

    public init(
        queries: [SearchQuery],
        options: SearchOptions = .defaults
    ) {
        self.init(
            probes: queries.map { query in
                SearchProbe(
                    query,
                    role: .preferred,
                    strategy: options.strategy
                )
            },
            options: options
        )
    }

    public init(
        _ query: SearchQuery,
        options: SearchOptions = .defaults
    ) {
        self.init(
            queries: [
                query,
            ],
            options: options
        )
    }

    public init(
        _ text: String,
        options: SearchOptions = .defaults
    ) {
        self.init(
            SearchQuery(
                text
            ),
            options: options
        )
    }
}
