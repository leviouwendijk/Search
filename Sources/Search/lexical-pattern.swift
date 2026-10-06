import Parsing

public indirect enum LexicalPattern:
    Sendable,
    Codable,
    Hashable
{
    /// Match one identifier-like token by spelling.
    ///
    /// Parsing keywords are admitted as identifier-like words so generic
    /// lexical search does not require a language-specific keyword table.
    case identifier(String)

    /// Match one punctuation/symbol token by its source spelling.
    case symbol(String)

    /// Match one exact Parsing token.
    case token(Token)

    /// Match any one non-trivia token.
    case any

    /// Match each child in order.
    case sequence([LexicalPattern])

    /// Match between `minimum` and `maximum` arbitrary non-trivia tokens.
    case gap(
        minimum: Int,
        maximum: Int
    )

    /// Capture the source range and tokens consumed by one child pattern.
    case capture(
        name: String,
        pattern: LexicalPattern
    )

    /// Match one bounded child zero or one times.
    case optional(LexicalPattern)
}
