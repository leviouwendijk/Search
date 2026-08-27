import Matching
import Position
import Search
import TestFlows

extension SearchFlowSuite {
    static var textRangeFlow: TestFlow {
        TestFlow(
            "text-search-ranges",
            tags: [
                "search",
                "text",
                "position",
                "contains",
            ]
        ) {
            Step(
                "contains returns every occurrence with canonical character offsets"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: "alpha\n🐕 beta\nalpha"
                    )
                )

                let result = TextSearch.search(
                    "alpha",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .contains,
                        caseSensitive: true
                    )
                )

                try Expect.equal(
                    result.hits.count,
                    1,
                    "search.range.hit-count"
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
                        13,
                    ],
                    "search.range.start-offsets"
                )

                try Expect.equal(
                    spans.map {
                        $0.range.end.offset
                    },
                    [
                        5,
                        18,
                    ],
                    "search.range.end-offsets"
                )

                try Expect.equal(
                    spans.map {
                        $0.lineRange.start
                    },
                    [
                        1,
                        3,
                    ],
                    "search.range.lines"
                )
            }
        }
    }

    static var queryConvergenceFlow: TestFlow {
        TestFlow(
            "text-search-query-convergence",
            tags: [
                "search",
                "query",
                "ranking",
                "convergence",
            ]
        ) {
            Step(
                "independent query evidence converges on the strongest document"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "strong",
                        text: "tool mutation disposition skip sibling"
                    ),
                    SearchDocument(
                        id: "partial",
                        text: "tool mutation"
                    ),
                    SearchDocument(
                        id: "unrelated",
                        text: "accounting calendar"
                    )
                )

                let result = TextSearch.search(
                    [
                        SearchQuery(
                            "tool mutation",
                            id: "mutation"
                        ),
                        SearchQuery(
                            "skip sibling",
                            id: "sibling"
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        strategy: .contains,
                        caseSensitive: false,
                        maximumResults: 3
                    )
                )

                try Expect.equal(
                    result.candidateCount,
                    2,
                    "search.convergence.candidate-count"
                )

                try Expect.equal(
                    result.hits.map(\.documentID),
                    [
                        "strong",
                        "partial",
                    ],
                    "search.convergence.order"
                )

                try Expect.equal(
                    result.hits[0].evidence.count,
                    2,
                    "search.convergence.evidence-count"
                )
            }
        }
    }

    static var fuzzyFlow: TestFlow {
        TestFlow(
            "text-search-fuzzy",
            tags: [
                "search",
                "fuzzy",
                "ranking",
            ]
        ) {
            Step(
                "fuzzy search reuses the shared Matching Fuzzy Ranking stack"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "runtime",
                        text: "tool mutation disposition"
                    ),
                    SearchDocument(
                        id: "other",
                        text: "calendar availability"
                    )
                )

                let result = TextSearch.search(
                    "tool mutation",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .fuzzy,
                        caseSensitive: false
                    )
                )

                try Expect.equal(
                    result.hits.map(\.documentID),
                    [
                        "runtime",
                    ],
                    "search.fuzzy.matches"
                )
            }
        }
    }
}
