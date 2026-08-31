public struct SearchResult<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let mode: SearchMode
    public let probes: [SearchProbe]
    public let queries: [SearchQuery]
    public let searchedDocumentCount: Int
    public let matchedDocumentCount: Int
    public let candidateCount: Int
    public let hits: [SearchHit<ID>]

    public init(
        mode: SearchMode = .ranked,
        probes: [SearchProbe],
        searchedDocumentCount: Int,
        matchedDocumentCount: Int,
        hits: [SearchHit<ID>]
    ) {
        self.mode = mode
        self.probes = probes
        self.queries = probes.map(\.query)
        self.searchedDocumentCount = searchedDocumentCount
        self.matchedDocumentCount = matchedDocumentCount
        self.candidateCount = matchedDocumentCount
        self.hits = hits
    }

    public init(
        mode: SearchMode = .ranked,
        queries: [SearchQuery],
        searchedDocumentCount: Int,
        matchedDocumentCount: Int,
        hits: [SearchHit<ID>]
    ) {
        self.mode = mode
        self.probes = []
        self.queries = queries
        self.searchedDocumentCount = searchedDocumentCount
        self.matchedDocumentCount = matchedDocumentCount
        self.candidateCount = matchedDocumentCount
        self.hits = hits
    }

    public init(
        queries: [SearchQuery],
        searchedDocumentCount: Int,
        candidateCount: Int,
        hits: [SearchHit<ID>]
    ) {
        self.init(
            mode: .ranked,
            queries: queries,
            searchedDocumentCount: searchedDocumentCount,
            matchedDocumentCount: candidateCount,
            hits: hits
        )
    }

    public var returnedHitCount: Int {
        hits.count
    }

    public var truncated: Bool {
        returnedHitCount < matchedDocumentCount
    }

    public var hasMore: Bool {
        truncated
    }
}

extension SearchResult: Codable where ID: Codable {}
