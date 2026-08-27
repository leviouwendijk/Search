public struct SearchResult<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let queries: [SearchQuery]
    public let searchedDocumentCount: Int
    public let candidateCount: Int
    public let hits: [SearchHit<ID>]

    public init(
        queries: [SearchQuery],
        searchedDocumentCount: Int,
        candidateCount: Int,
        hits: [SearchHit<ID>]
    ) {
        self.queries = queries
        self.searchedDocumentCount = searchedDocumentCount
        self.candidateCount = candidateCount
        self.hits = hits
    }

    public var returnedHitCount: Int {
        hits.count
    }
}

extension SearchResult: Codable where ID: Codable {}
