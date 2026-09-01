import Search
import TestFlows

extension SearchFlowSuite {
    static var probeSemanticsFlow: TestFlow {
        TestFlow(
            "search-rich-probe-semantics",
            tags: [
                "search",
                "probe",
                "required",
                "preferred",
                "excluded",
            ]
        ) {
            Step(
                "required preferred and excluded probes control document admission independently"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "plain",
                        text: "ToolPlan resume"
                    ),
                    SearchDocument(
                        id: "strong",
                        text: "ToolPlan resume failure"
                    ),
                    SearchDocument(
                        id: "embedded",
                        text: "ToolPlanState resume failure"
                    ),
                    SearchDocument(
                        id: "missing-required",
                        text: "ToolPlan failure"
                    ),
                    SearchDocument(
                        id: "excluded",
                        text: "ToolPlan resume failure Deprecated"
                    )
                )

                let probes: [SearchProbe] = [
                    SearchProbe(
                        "ToolPlan",
                        id: "type",
                        role: .required,
                        strategy: .identifier
                    ),
                    SearchProbe(
                        "resume",
                        id: "operation",
                        role: .required,
                        strategy: .contains
                    ),
                    SearchProbe(
                        "failure",
                        id: "context",
                        role: .preferred,
                        strategy: .identifier
                    ),
                    SearchProbe(
                        "Deprecated",
                        id: "deprecated",
                        role: .excluded,
                        strategy: .identifier
                    ),
                ]

                let result = TextSearch.search(
                    probes: probes,
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )

                try Expect.equal(
                    result.hits.map(\.documentID),
                    [
                        "plain",
                        "strong",
                    ],
                    "required probes constrain admission, excluded probes veto, and preferred probes remain optional"
                )
                try Expect.equal(
                    result.matchedDocumentCount,
                    2,
                    "probe admission count reflects the semantic document universe"
                )
                try Expect.equal(
                    result.probes,
                    probes,
                    "search results preserve the authored probe request"
                )

                let strong = try Expect.notNil(
                    result.hits.first {
                        $0.documentID == "strong"
                    },
                    "strong probe candidate exists"
                )

                try Expect.equal(
                    strong.evidence.map(\.role),
                    [
                        .required,
                        .required,
                        .preferred,
                    ],
                    "positive evidence retains required and preferred roles"
                )
                try Expect.equal(
                    strong.evidence.map(\.strategy),
                    [
                        .identifier,
                        .contains,
                        .identifier,
                    ],
                    "each probe retains its independently authored matching strategy"
                )
            }

            Step(
                "preferred evidence ranks stronger documents without becoming an admission requirement"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "plain",
                        text: "ToolPlan resume"
                    ),
                    SearchDocument(
                        id: "strong",
                        text: "ToolPlan resume failure"
                    )
                )

                let result = TextSearch.search(
                    probes: [
                        SearchProbe(
                            "ToolPlan",
                            role: .required,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "resume",
                            role: .required,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "failure",
                            role: .preferred,
                            strategy: .identifier
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        mode: .ranked,
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )

                try Expect.equal(
                    result.hits.map(\.documentID),
                    [
                        "strong",
                        "plain",
                    ],
                    "preferred evidence strengthens ranking without filtering the plain required-only match"
                )
            }

            Step(
                "excluded-only searches do not manufacture evidence-free hits"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "clean",
                        text: "active implementation"
                    ),
                    SearchDocument(
                        id: "deprecated",
                        text: "Deprecated implementation"
                    )
                )

                let result = TextSearch.search(
                    probes: [
                        SearchProbe(
                            "Deprecated",
                            role: .excluded,
                            strategy: .identifier
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )

                try Expect.equal(
                    result.hits.isEmpty,
                    true,
                    "negative-only probes filter but do not synthesize source evidence"
                )
            }

            Step(
                "legacy query requests remain preferred probes using the shared option strategy"
            ) {
                let request = SearchRequest(
                    queries: [
                        SearchQuery(
                            "Foo",
                            id: "legacy"
                        ),
                    ],
                    options: SearchOptions(
                        strategy: .identifier,
                        caseSensitive: true
                    )
                )

                try Expect.equal(
                    request.probes.map(\.role),
                    [
                        .preferred,
                    ],
                    "legacy SearchQuery requests retain existing OR-style preferred semantics"
                )
                try Expect.equal(
                    request.probes.map(\.strategy),
                    [
                        .identifier,
                    ],
                    "legacy SearchOptions.strategy remains the default strategy adapter"
                )
            }

            Step(
                "frontier convergence preserves probe role and strategy provenance"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "runtime",
                        text: """
                        ToolPlan
                        resume
                        failure
                        """
                    )
                )

                let result = TextSearch.search(
                    probes: [
                        SearchProbe(
                            "ToolPlan",
                            id: "type",
                            role: .required,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "resume",
                            id: "operation",
                            role: .required,
                            strategy: .contains
                        ),
                        SearchProbe(
                            "failure",
                            id: "context",
                            role: .preferred,
                            strategy: .identifier
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )
                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 1,
                        maximumCandidates: nil
                    )
                )

                try Expect.equal(
                    frontier.count,
                    1,
                    "nearby rich probe evidence still converges into one frontier region"
                )
                try Expect.equal(
                    frontier.candidates[0].evidence.map(\.role),
                    [
                        .required,
                        .required,
                        .preferred,
                    ],
                    "frontier evidence preserves probe roles"
                )
                try Expect.equal(
                    frontier.candidates[0].evidence.map(\.strategy),
                    [
                        .identifier,
                        .contains,
                        .identifier,
                    ],
                    "frontier evidence preserves independently selected strategies"
                )
            }

            Step(
                "required evidence anchors frontier regions without suppressing nearby preferred evidence"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "anchored",
                        text: """
                        Anchor
                        nearby
                        gap
                        gap
                        distant
                        """
                    )
                )

                let anchored = TextSearch.search(
                    probes: [
                        SearchProbe(
                            "Anchor",
                            id: "anchor",
                            role: .required,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "nearby",
                            id: "nearby",
                            role: .preferred,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "distant",
                            id: "distant",
                            weight: 8,
                            role: .preferred,
                            strategy: .identifier
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )
                let anchoredFrontier = anchored.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 1,
                        maximumCandidates: nil
                    )
                )

                try Expect.equal(
                    anchoredFrontier.count,
                    1,
                    "distant preferred evidence does not create an unanchored frontier candidate"
                )
                try Expect.equal(
                    anchoredFrontier.candidates[0].evidence.compactMap(\.queryID),
                    [
                        "anchor",
                        "nearby",
                    ],
                    "nearby preferred evidence still enriches the required-anchored candidate"
                )

                let preferredOnly = TextSearch.search(
                    probes: [
                        SearchProbe(
                            "nearby",
                            id: "nearby",
                            role: .preferred,
                            strategy: .identifier
                        ),
                        SearchProbe(
                            "distant",
                            id: "distant",
                            role: .preferred,
                            strategy: .identifier
                        ),
                    ],
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        caseSensitive: true,
                        maximumResults: nil
                    )
                )
                let preferredOnlyFrontier = preferredOnly.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 1,
                        maximumCandidates: nil
                    )
                )

                try Expect.equal(
                    preferredOnlyFrontier.count,
                    2,
                    "preferred-only searches continue to seed independent frontier regions"
                )
            }
        }
    }
}
