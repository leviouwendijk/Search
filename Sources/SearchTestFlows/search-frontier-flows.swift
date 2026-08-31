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

    static var frontierDocumentDiversityFlow: TestFlow {
        TestFlow(
            "search-frontier-document-diversity",
            tags: [
                "search",
                "frontier",
                "diversity",
            ]
        ) {
            Step(
                "optional per-document cap preserves globally ranked diversity"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "dominant",
                        text: """
                        needle
                        gap
                        needle
                        gap
                        needle
                        """
                    ),
                    SearchDocument(
                        id: "secondary",
                        text: "needle"
                    )
                )

                let result = TextSearch.search(
                    "needle",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .contains,
                        caseSensitive: true
                    )
                )

                let unrestricted = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2
                    )
                )

                try Expect.equal(
                    unrestricted.candidates.map(\.documentID),
                    [
                        "dominant",
                        "dominant",
                    ],
                    "frontier without diversity cap preserves global ranking"
                )

                let diversified = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2,
                        maximumCandidatesPerDocument: 1
                    )
                )

                try Expect.equal(
                    diversified.candidates.map(\.documentID),
                    [
                        "dominant",
                        "secondary",
                    ],
                    "frontier diversity admits another ranked document"
                )
            }
        }
    }
}
