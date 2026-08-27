public struct SearchRequest:
    Sendable,
    Codable,
    Hashable
{
    public let queries: [SearchQuery]
    public let options: SearchOptions

    public init(
        queries: [SearchQuery],
        options: SearchOptions = .defaults
    ) {
        self.queries = queries
        self.options = options
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
