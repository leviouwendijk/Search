import Parsing
import Position
import Search
import Testing

extension SearchTestSuite {
    static var lexicalSearchSuite: TestSuite {
        TestSuite(
            "lexical-search-patterns",
            tags: [
                "search",
                "lexical",
                "parsing",
                "position",
            ]
        ) {
            Test(
                "ordered identifier and symbol patterns match syntax-shaped token sequences"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: """
                        foo.bar()
                        foo . baz()
                        """
                    )
                )
                let result = LexicalSearch.search(
                    .sequence(
                        [
                            .identifier("foo"),
                            .symbol("."),
                            .identifier("bar"),
                            .symbol("("),
                            .symbol(")"),
                        ]
                    ),
                    in: corpus
                )

                try Expect.equal(
                    result.matchCount,
                    1,
                    "lexical ordered sequence admits only the requested token shape"
                )
                try Expect.equal(
                    result.matches[0].lineRange,
                    LineRange(
                        uncheckedStart: 1,
                        uncheckedEnd: 1
                    ),
                    "lexical match preserves source line coordinates"
                )
            }

            Test(
                "exact token matching distinguishes one arrow token from adjacent punctuation"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: """
                        lhs -> rhs
                        lhs - > rhs
                        """
                    )
                )
                let result = LexicalSearch.search(
                    .sequence(
                        [
                            .identifier("lhs"),
                            .token(.arrow),
                            .identifier("rhs"),
                        ]
                    ),
                    in: corpus
                )

                try Expect.equal(
                    result.matchCount,
                    1,
                    "exact lexical tokens preserve lexer token identity"
                )
                try Expect.equal(
                    result.matches[0].lineRange.start,
                    1,
                    "exact token match resolves to the first source line"
                )
            }

            Test(
                "bounded gaps, captures, and optional elements remain deterministic"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: """
                        call(foo)
                        call foo
                        alpha one two beta
                        alpha one two three beta
                        """
                    )
                )
                let calls = LexicalSearch.search(
                    .sequence(
                        [
                            .identifier("call"),
                            .optional(
                                .symbol("(")
                            ),
                            .capture(
                                name: "argument",
                                pattern: .identifier("foo")
                            ),
                            .optional(
                                .symbol(")")
                            ),
                        ]
                    ),
                    in: corpus
                )
                let boundedGap = LexicalSearch.search(
                    .sequence(
                        [
                            .identifier("alpha"),
                            .gap(
                                minimum: 1,
                                maximum: 2
                            ),
                            .identifier("beta"),
                        ]
                    ),
                    in: corpus
                )

                try Expect.equal(
                    calls.matchCount,
                    2,
                    "optional lexical elements admit both bounded call shapes"
                )
                try Expect.equal(
                    calls.matches.map {
                        $0.captures.first?.tokens
                    },
                    [
                        [
                            .identifier("foo"),
                        ],
                        [
                            .identifier("foo"),
                        ],
                    ],
                    "lexical captures preserve the exact consumed tokens"
                )
                try Expect.equal(
                    boundedGap.matchCount,
                    1,
                    "bounded lexical gaps cannot silently consume beyond their maximum"
                )
                try Expect.equal(
                    boundedGap.matches[0].lineRange.start,
                    3,
                    "bounded gap match keeps original line coordinates"
                )
            }

            Test(
                "identifier matching supports explicit case policy"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: "Tool tool"
                    )
                )
                let sensitive = LexicalSearch.search(
                    .identifier("tool"),
                    in: corpus,
                    caseSensitive: true
                )
                let insensitive = LexicalSearch.search(
                    .identifier("tool"),
                    in: corpus,
                    caseSensitive: false
                )

                try Expect.equal(
                    sensitive.matchCount,
                    1,
                    "case-sensitive lexical identifiers preserve spelling"
                )
                try Expect.equal(
                    insensitive.matchCount,
                    2,
                    "case-insensitive lexical identifiers admit equivalent spelling"
                )
            }
        }
    }
}
