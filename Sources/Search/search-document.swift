import Matching

public struct SearchDocument<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let id: ID
    public let text: String

    public init(
        id: ID,
        text: String
    ) {
        self.id = id
        self.text = text
    }
}

extension SearchDocument: Codable where ID: Codable {}

extension SearchDocument: MatchCandidate {
    public var matchID: ID {
        id
    }

    public var primaryField: MatchField {
        MatchField(
            name: "text",
            text: text,
            role: .primary
        )
    }

    public var secondaryFields: [MatchField] {
        []
    }

    public var metadata: MatchCandidateMetadata {
        .init()
    }
}
