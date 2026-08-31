import Search
import TestFlows

extension SearchFlowSuite {
    static var identifierRangeFlow: TestFlow {
        TestFlow(
            "text-search-identifier-ranges",
            tags: [
                "search",
                "text",
                "identifier",
                "position",
            ]
        ) {
            Step(
                "identifier matching accepts bounded source identifiers and rejects embedded components"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: "Foo FooBar MyFoo Foo2 2Foo _Foo Foo_ Foo() .Foo [Foo] foo"
                    )
                )

                let result = TextSearch.search(
                    "Foo",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .identifier,
                        caseSensitive: true
                    )
                )

                try Expect.equal(
                    result.hits.count,
                    1,
                    "identifier search returns the matching source document"
                )

                let evidence = result.hits[0].evidence[0]

                try Expect.equal(
                    evidence.strategy,
                    .identifier,
                    "identifier evidence preserves the matching strategy"
                )

                try Expect.equal(
                    evidence.spans.map {
                        $0.range.start.offset
                    },
                    [
                        0,
                        37,
                        44,
                        49,
                    ],
                    "identifier search excludes FooBar, MyFoo, Foo2, 2Foo, _Foo, and Foo_"
                )

                try Expect.equal(
                    evidence.spans.map {
                        $0.range.end.offset
                    },
                    [
                        3,
                        40,
                        47,
                        52,
                    ],
                    "identifier search preserves canonical half-open ranges"
                )
            }

            Step(
                "identifier matching preserves ordinary case policy"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: "Foo foo FooBar"
                    )
                )

                let result = TextSearch.search(
                    "foo",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .identifier,
                        caseSensitive: false
                    )
                )

                let spans = result.hits[0]
                    .evidence[0]
                    .spans

                try Expect.equal(
                    spans.map {
                        $0.range.start.offset
                    },
                    [
                        0,
                        4,
                    ],
                    "case-insensitive identifier search still rejects embedded identifier components"
                )
            }

            Step(
                "identifier matching rejects punctuated queries rather than becoming contains"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: "Foo.bar Foo.bar"
                    )
                )

                let result = TextSearch.search(
                    "Foo.bar",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .identifier,
                        caseSensitive: true
                    )
                )

                try Expect.equal(
                    result.hits.isEmpty,
                    true,
                    "identifier strategy is restricted to identifier-member queries"
                )
            }
        }
    }
}
