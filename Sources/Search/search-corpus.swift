public struct SearchCorpus<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let documents: [SearchDocument<ID>]

    public init(
        documents: [SearchDocument<ID>]
    ) {
        self.documents = documents
    }

    public init(
        _ documents: SearchDocument<ID>...
    ) {
        self.init(
            documents: documents
        )
    }

    public var isEmpty: Bool {
        documents.isEmpty
    }

    public var count: Int {
        documents.count
    }
}

extension SearchCorpus: Codable where ID: Codable {}
