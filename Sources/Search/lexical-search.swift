import Foundation
import Parsing
import Position

public enum LexicalSearch {
    public static func search<ID: Hashable & Sendable>(
        _ pattern: LexicalPattern,
        in corpus: SearchCorpus<ID>,
        caseSensitive: Bool = true
    ) -> LexicalSearchResult<ID> {
        var collectedMatches: [LexicalMatch<ID>] = []
        var matchedDocuments: Set<ID> = []

        for document in corpus.documents {
            let documentMatches = matches(
                pattern,
                in: document,
                caseSensitive: caseSensitive
            )

            guard !documentMatches.isEmpty else {
                continue
            }

            matchedDocuments.insert(
                document.id
            )
            collectedMatches.append(
                contentsOf: documentMatches
            )
        }

        return LexicalSearchResult(
            searchedDocumentCount: corpus.count,
            matchedDocumentCount: matchedDocuments.count,
            matches: collectedMatches
        )
    }
}

private extension LexicalSearch {
    struct MatchState {
        var tokenIndex: Int
        var captures: [PendingCapture]
    }

    struct PendingCapture {
        let name: String
        let startTokenIndex: Int
        let endTokenIndex: Int
    }

    static func matches<ID: Hashable & Sendable>(
        _ pattern: LexicalPattern,
        in document: SearchDocument<ID>,
        caseSensitive: Bool
    ) -> [LexicalMatch<ID>] {
        let tokens = lex(
            document.text
        )

        guard !tokens.isEmpty else {
            return []
        }

        var matches: [LexicalMatch<ID>] = []
        var seen: Set<LexicalMatch<ID>> = []

        for startTokenIndex in tokens.indices {
            let initial = MatchState(
                tokenIndex: startTokenIndex,
                captures: []
            )
            let states = match(
                pattern,
                tokens: tokens,
                from: initial,
                caseSensitive: caseSensitive
            )

            guard let state = states
                .filter({
                    $0.tokenIndex > startTokenIndex
                })
                .max(by: { lhs, rhs in
                    lhs.tokenIndex < rhs.tokenIndex
                })
            else {
                continue
            }

            guard let lexicalMatch = lexicalMatch(
                documentID: document.id,
                text: document.text,
                tokens: tokens,
                startTokenIndex: startTokenIndex,
                state: state
            ) else {
                continue
            }

            if seen.insert(lexicalMatch).inserted {
                matches.append(
                    lexicalMatch
                )
            }
        }

        return matches.sorted { lhs, rhs in
            if lhs.range.start.offset != rhs.range.start.offset {
                return lhs.range.start.offset < rhs.range.start.offset
            }

            return lhs.range.end.offset < rhs.range.end.offset
        }
    }

    static func lex(
        _ text: String
    ) -> [LexedToken] {
        var options = LexerOptions()
        options.identifier_continuation = .punctuation_delimited
        options.emit_whitespace = false
        options.emit_newlines = false
        options.emit_comments = false

        var lexer = Lexer(
            source: text,
            sets: LexingSets(
                keywords: []
            ),
            options: options
        )

        return lexer.lexedTokens().filter { lexed in
            lexed.token != .eof
                && !lexed.token.is_trivia
        }
    }

    static func match(
        _ pattern: LexicalPattern,
        tokens: [LexedToken],
        from state: MatchState,
        caseSensitive: Bool
    ) -> [MatchState] {
        switch pattern {
        case .identifier(let expected):
            guard
                state.tokenIndex < tokens.count,
                matchesIdentifier(
                    tokens[state.tokenIndex].token,
                    expected: expected,
                    caseSensitive: caseSensitive
                )
            else {
                return []
            }

            return [
                MatchState(
                    tokenIndex: state.tokenIndex + 1,
                    captures: state.captures
                ),
            ]

        case .symbol(let expected):
            guard
                state.tokenIndex < tokens.count,
                tokens[state.tokenIndex].token.is_punctuation,
                equals(
                    tokens[state.tokenIndex].token.string(),
                    expected,
                    caseSensitive: caseSensitive
                )
            else {
                return []
            }

            return [
                MatchState(
                    tokenIndex: state.tokenIndex + 1,
                    captures: state.captures
                ),
            ]

        case .token(let expected):
            guard
                state.tokenIndex < tokens.count,
                tokens[state.tokenIndex].token == expected
            else {
                return []
            }

            return [
                MatchState(
                    tokenIndex: state.tokenIndex + 1,
                    captures: state.captures
                ),
            ]

        case .any:
            guard state.tokenIndex < tokens.count else {
                return []
            }

            return [
                MatchState(
                    tokenIndex: state.tokenIndex + 1,
                    captures: state.captures
                ),
            ]

        case .sequence(let patterns):
            return patterns.reduce(
                [
                    state,
                ]
            ) { states, child in
                states.flatMap { state in
                    match(
                        child,
                        tokens: tokens,
                        from: state,
                        caseSensitive: caseSensitive
                    )
                }
            }

        case .gap(let minimum, let maximum):
            guard
                minimum >= 0,
                maximum >= minimum,
                state.tokenIndex + minimum <= tokens.count
            else {
                return []
            }

            let upperBound = min(
                maximum,
                tokens.count - state.tokenIndex
            )

            return (minimum...upperBound).map { distance in
                MatchState(
                    tokenIndex: state.tokenIndex + distance,
                    captures: state.captures
                )
            }

        case .capture(let name, let child):
            let startTokenIndex = state.tokenIndex

            return match(
                child,
                tokens: tokens,
                from: state,
                caseSensitive: caseSensitive
            ).map { matched in
                guard matched.tokenIndex > startTokenIndex else {
                    return matched
                }

                var captures = matched.captures
                captures.append(
                    PendingCapture(
                        name: name,
                        startTokenIndex: startTokenIndex,
                        endTokenIndex: matched.tokenIndex
                    )
                )

                return MatchState(
                    tokenIndex: matched.tokenIndex,
                    captures: captures
                )
            }

        case .optional(let child):
            return [
                state,
            ] + match(
                child,
                tokens: tokens,
                from: state,
                caseSensitive: caseSensitive
            )
        }
    }

    static func matchesIdentifier(
        _ token: Token,
        expected: String,
        caseSensitive: Bool
    ) -> Bool {
        switch token {
        case .identifier(let actual),
             .keyword(let actual):
            return equals(
                actual,
                expected,
                caseSensitive: caseSensitive
            )

        default:
            return false
        }
    }

    static func equals(
        _ lhs: String,
        _ rhs: String,
        caseSensitive: Bool
    ) -> Bool {
        if caseSensitive {
            return lhs == rhs
        }

        return lhs.caseInsensitiveCompare(
            rhs
        ) == .orderedSame
    }

    static func lexicalMatch<ID: Hashable & Sendable>(
        documentID: ID,
        text: String,
        tokens: [LexedToken],
        startTokenIndex: Int,
        state: MatchState
    ) -> LexicalMatch<ID>? {
        guard
            startTokenIndex < tokens.count,
            state.tokenIndex > startTokenIndex,
            state.tokenIndex <= tokens.count
        else {
            return nil
        }

        let endTokenIndex = state.tokenIndex - 1
        let range = PositionRange(
            uncheckedStart: tokens[startTokenIndex].range.start,
            uncheckedEnd: tokens[endTokenIndex].range.end
        )
        let lineRange = lineRange(
            for: range,
            in: text
        )
        let captures = state.captures.compactMap { capture in
            lexicalCapture(
                capture,
                text: text,
                tokens: tokens
            )
        }

        return LexicalMatch(
            documentID: documentID,
            range: range,
            lineRange: lineRange,
            captures: captures
        )
    }

    static func lexicalCapture(
        _ capture: PendingCapture,
        text: String,
        tokens: [LexedToken]
    ) -> LexicalCapture? {
        guard
            capture.startTokenIndex >= 0,
            capture.endTokenIndex > capture.startTokenIndex,
            capture.endTokenIndex <= tokens.count
        else {
            return nil
        }

        let endTokenIndex = capture.endTokenIndex - 1
        let range = PositionRange(
            uncheckedStart: tokens[capture.startTokenIndex].range.start,
            uncheckedEnd: tokens[endTokenIndex].range.end
        )

        return LexicalCapture(
            name: capture.name,
            range: range,
            lineRange: lineRange(
                for: range,
                in: text
            ),
            tokens: tokens[
                capture.startTokenIndex..<capture.endTokenIndex
            ].map(
                \.token
            )
        )
    }

    static func lineRange(
        for range: PositionRange,
        in text: String
    ) -> LineRange {
        let startLine = lineNumber(
            atCharacterOffset: range.start.offset,
            in: text
        )
        let inclusiveEndOffset = max(
            range.start.offset,
            range.end.offset - 1
        )
        let endLine = lineNumber(
            atCharacterOffset: inclusiveEndOffset,
            in: text
        )

        return LineRange(
            uncheckedStart: startLine,
            uncheckedEnd: endLine
        )
    }

    static func lineNumber(
        atCharacterOffset offset: Int,
        in text: String
    ) -> Int {
        let boundedOffset = min(
            max(
                0,
                offset
            ),
            text.count
        )
        let end = text.index(
            text.startIndex,
            offsetBy: boundedOffset
        )

        return text[..<end].reduce(
            into: 1
        ) { line, character in
            if character == "\n" {
                line += 1
            }
        }
    }
}
