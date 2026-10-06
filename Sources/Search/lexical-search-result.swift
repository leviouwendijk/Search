import Parsing
import Position

public struct LexicalCapture:
    Sendable,
    Codable,
    Hashable
{
    public let name: String
    public let range: PositionRange
    public let lineRange: LineRange
    public let tokens: [Token]

    public init(
        name: String,
        range: PositionRange,
        lineRange: LineRange,
        tokens: [Token]
    ) {
        self.name = name
        self.range = range
        self.lineRange = lineRange
        self.tokens = tokens
    }
}

public struct LexicalMatch<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let documentID: ID
    public let range: PositionRange
    public let lineRange: LineRange
    public let captures: [LexicalCapture]

    public init(
        documentID: ID,
        range: PositionRange,
        lineRange: LineRange,
        captures: [LexicalCapture] = []
    ) {
        self.documentID = documentID
        self.range = range
        self.lineRange = lineRange
        self.captures = captures
    }
}

extension LexicalMatch: Codable where ID: Codable {}

public struct LexicalSearchResult<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let searchedDocumentCount: Int
    public let matchedDocumentCount: Int
    public let matches: [LexicalMatch<ID>]

    public init(
        searchedDocumentCount: Int,
        matchedDocumentCount: Int,
        matches: [LexicalMatch<ID>]
    ) {
        self.searchedDocumentCount = searchedDocumentCount
        self.matchedDocumentCount = matchedDocumentCount
        self.matches = matches
    }

    public var matchCount: Int {
        matches.count
    }

    public var isEmpty: Bool {
        matches.isEmpty
    }
}

extension LexicalSearchResult: Codable where ID: Codable {}
