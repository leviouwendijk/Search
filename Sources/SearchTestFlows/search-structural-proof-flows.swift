import Matching
import Parsing
import Search
import TestFlows

extension SearchFlowSuite {
    static var structuralProofFlow: TestFlow {
        TestFlow(
            "search-structural-proof",
            tags: [
                "search",
                "frontier",
                "parsing",
                "proof",
                "position",
            ]
        ) {
            Step(
                "structural proof removes textual false positives"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "proven",
                        text: "header\nuser=Levi\ntail"
                    ),
                    SearchDocument(
                        id: "text-only",
                        text: "header\nuser Levi\ntail"
                    )
                )
                let result = TextSearch.search(
                    "user",
                    in: corpus,
                    options: SearchOptions(
                        strategy: .contains,
                        caseSensitive: true,
                        maximumResults: 2
                    )
                )
                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2
                    )
                )
                let proof = try frontier.prove(
                    in: corpus,
                    with: assignmentSpecification()
                )

                try Expect.equal(
                    frontier.count,
                    2,
                    "search.proof.textual-candidates"
                )
                try Expect.equal(
                    proof.provenCandidateCount,
                    1,
                    "search.proof.proven-candidates"
                )
                try Expect.equal(
                    proof.proofs.map(\.documentID),
                    [
                        "proven",
                    ],
                    "search.proof.document"
                )

                let match = try Expect.notNil(
                    proof.proofs.first?.matches.first,
                    "search.proof.match"
                )
                let capture = try Expect.notNil(
                    match.captures.first,
                    "search.proof.capture"
                )

                try Expect.equal(
                    match.range.start.offset,
                    7,
                    "search.proof.absolute-start"
                )
                try Expect.equal(
                    match.range.end.offset,
                    16,
                    "search.proof.absolute-end"
                )
                try Expect.equal(
                    capture.range.start.offset,
                    12,
                    "search.proof.capture-absolute-start"
                )
                try Expect.equal(
                    capture.range.end.offset,
                    16,
                    "search.proof.capture-absolute-end"
                )
                try Expect.equal(
                    capture.value,
                    "Levi",
                    "search.proof.capture-value"
                )
            }

            Step(
                "proof scans only the converged candidate line region and rebases ranges"
            ) {
                let source = """
                user=Outside
                noise
                needle user=Inside
                noise
                user=Outside2
                """
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "source",
                        text: source
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
                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0
                    )
                )
                let proof = try frontier.prove(
                    in: corpus,
                    with: assignmentSpecification()
                )
                let proven = try Expect.notNil(
                    proof.proofs.first,
                    "search.proof.region"
                )
                let match = try Expect.notNil(
                    proven.matches.first,
                    "search.proof.region-match"
                )

                try Expect.equal(
                    frontier.candidates.first?.lineRange.start,
                    3,
                    "search.proof.region-line"
                )
                try Expect.equal(
                    proven.matches.count,
                    1,
                    "search.proof.region-bounded-count"
                )
                try Expect.equal(
                    match.range.start.offset,
                    26,
                    "search.proof.region-absolute-start"
                )
                try Expect.equal(
                    match.range.end.offset,
                    37,
                    "search.proof.region-absolute-end"
                )
                try Expect.equal(
                    match.captures.first?.range.start.offset,
                    31,
                    "search.proof.region-capture-start"
                )
                try Expect.equal(
                    match.captures.first?.range.end.offset,
                    37,
                    "search.proof.region-capture-end"
                )
                try Expect.equal(
                    match.captures.first?.value,
                    "Inside",
                    "search.proof.region-capture-value"
                )
            }

            Step(
                "grammar references and cardinality remain Parsing-owned proof semantics"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "double",
                        text: "needle user=One user=Two"
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
                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0
                    )
                )
                let grammar = StructuredParser.Grammar(
                    root: .sequence(
                        [
                            .literal("user="),
                            .capture(
                                name: "name",
                                specification: .reference("value")
                            ),
                        ]
                    ),
                    definitions: [
                        .init(
                            name: "value",
                            specification: .identifier
                        ),
                    ]
                )

                let exactlyTwo = try frontier.prove(
                    in: corpus,
                    with: grammar,
                    requiring: .exactly(2)
                )
                let exactlyOne = try frontier.prove(
                    in: corpus,
                    with: grammar,
                    requiring: .exactlyOne
                )

                try Expect.equal(
                    exactlyTwo.provenCandidateCount,
                    1,
                    "search.proof.cardinality-two"
                )
                try Expect.equal(
                    exactlyTwo.matchCount,
                    2,
                    "search.proof.cardinality-two-matches"
                )
                try Expect.equal(
                    exactlyTwo.proofs.first?.matches.map {
                        $0.captures.first?.value
                    },
                    [
                        "One",
                        "Two",
                    ],
                    "search.proof.grammar-captures"
                )
                try Expect.equal(
                    exactlyOne.provenCandidateCount,
                    0,
                    "search.proof.cardinality-one-rejected"
                )
            }
        }
    }

    private static func assignmentSpecification() -> StructuredParser.Specification {
        .sequence(
            [
                .literal("user="),
                .capture(
                    name: "name",
                    specification: .identifier
                ),
            ]
        )
    }
}
