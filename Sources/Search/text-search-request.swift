public extension TextSearch {
    static func search<ID: Hashable & Sendable>(
        _ request: SearchRequest,
        in corpus: SearchCorpus<ID>
    ) -> SearchResult<ID> {
        search(
            request.queries,
            in: corpus,
            options: request.options
        )
    }
}
