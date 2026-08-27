import Matching
import Search
import TestFlows

extension SearchFlowSuite {
    static var frontierConvergenceFlow: TestFlow {
        TestFlow(
            "search-frontier-convergence",
            tags: [
                "search",
                "frontier",
                "convergence",
            ]
        ) {
            Step(
                "nearby independent probes merge into one candidate region"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "runtime",
                        text: """
                        opening
                        tool mutation
                        nearby context
                        skip sibling
                        closing
                        """
                    )
                )

                let result = TextSearch.search(
                    SearchRequest(
                        queries: [
                            SearchQuery(
                                "tool mutation",
                                id: "mutation"
                            ),
                            SearchQuery(
                                "skip sibling",
                                id: "sibling"
                            ),
                        ],
                        options: SearchOptions(
                            strategy: .contains,
                            caseSensitive: true
                        )
                    ),
                    in: corpus
                )

                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 1
                    )
                )

                try Expect.equal(
                    frontier.count,
                    1,
                    "search.frontier.converged-count"
                )

                try Expect.equal(
                    frontier.candidates[0].lineRange.start,
                    2,
                    "search.frontier.converged-start"
                )

                try Expect.equal(
                    frontier.candidates[0].lineRange.end,
                    4,
                    "search.frontier.converged-end"
                )

                try Expect.equal(
                    frontier.candidates[0].probeCount,
                    2,
                    "search.frontier.converged-probes"
                )
            }
        }
    }

    static var frontierSeparationFlow: TestFlow {
        TestFlow(
            "search-frontier-separation",
            tags: [
                "search",
                "frontier",
                "separation",
            ]
        ) {
            Step(
                "distant evidence remains separate candidate regions"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: """
                        alpha
                        one
                        two
                        three
                        four
                        five
                        beta
                        """
                    )
                )

                let result = TextSearch.search(
                    [
                        SearchQuery(
                            "alpha",
                            id: "alpha"
                        ),
                        SearchQuery(
                            "beta",
                            id: "beta"
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        strategy: .contains,
                        caseSensitive: true
                    )
                )

                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 1
                    )
                )

                try Expect.equal(
                    frontier.count,
                    2,
                    "search.frontier.separate-count"
                )

                try Expect.equal(
                    frontier.candidates.map {
                        $0.lineRange.start
                    },
                    [
                        1,
                        7,
                    ],
                    "search.frontier.separate-lines"
                )
            }
        }
    }
}
