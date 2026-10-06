import Parsing
import Position
import Search
import Testing

extension SearchTestSuite {
    static var structuralAccelerationSuite: TestSuite {
        TestSuite(
            "structural-search-acceleration",
            tags: [
                "search",
                "structural",
                "parsing",
                "anchor",
            ]
        ) {
            Test(
                "required literals preselect documents while proof remains authoritative"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "valid",
                        text: """
                        header
                        user=Levi
                        tail
                        """
                    ),
                    SearchDocument(
                        id: "anchor-only",
                        text: """
                        header
                        user=123
                        tail
                        """
                    ),
                    SearchDocument(
                        id: "irrelevant",
                        text: """
                        header
                        account Levi
                        tail
                        """
                    )
                )
                let specification = StructuredParser.Specification.sequence(
                    [
                        .literal("user="),
                        .identifier,
                    ]
                )
                let frontier = try StructuralSearch.frontier(
                    in: corpus,
                    with: specification
                )

                try Expect.equal(
                    frontier.candidates.map(\.documentID),
                    [
                        "valid",
                        "anchor-only",
                    ],
                    "required literal evidence excludes documents that cannot contain a structural match"
                )
                try Expect.equal(
                    frontier.candidates.map(\.lineRange),
                    [
                        LineRange(
                            uncheckedStart: 1,
                            uncheckedEnd: 3
                        ),
                        LineRange(
                            uncheckedStart: 1,
                            uncheckedEnd: 3
                        ),
                    ],
                    "anchor acceleration admits full documents rather than unsafely narrowing proof regions"
                )
                try Expect.equal(
                    frontier.candidates.flatMap(\.evidence).allSatisfy {
                        $0.role == .required
                            && $0.strategy == .contains
                    },
                    true,
                    "Parsing-owned anchors become ordinary required Search evidence"
                )

                let proof = try StructuralSearch.prove(
                    in: corpus,
                    with: specification
                )

                try Expect.equal(
                    proof.candidateCount,
                    2,
                    "structural proof scans only documents admitted by safe required anchors"
                )
                try Expect.equal(
                    proof.proofs.map(\.documentID),
                    [
                        "valid",
                    ],
                    "anchor admission remains necessary evidence only; Parsing still decides structural truth"
                )
            }

            Test(
                "anchorless specifications fall back to full-corpus structural proof"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "identifier",
                        text: "alpha"
                    ),
                    SearchDocument(
                        id: "non-identifier",
                        text: "123"
                    )
                )
                let specification = StructuredParser.Specification.identifier
                let frontier = try StructuralSearch.frontier(
                    in: corpus,
                    with: specification
                )

                try Expect.equal(
                    frontier.candidates.map(\.documentID),
                    [
                        "identifier",
                        "non-identifier",
                    ],
                    "absence of provably required literals never excludes a document"
                )

                let proof = try StructuralSearch.prove(
                    in: corpus,
                    with: specification
                )

                try Expect.equal(
                    proof.candidateCount,
                    corpus.count,
                    "anchorless structural search preserves the existing full scan fallback"
                )
                try Expect.equal(
                    proof.proofs.map(\.documentID),
                    [
                        "identifier",
                    ],
                    "fallback still delegates exact semantics to StructuredParser"
                )
            }

            Test(
                "compiled grammar anchors accelerate admission after reference resolution"
            ) {
                let grammar = StructuredParser.Grammar(
                    root: .sequence(
                        [
                            .literal("let "),
                            .reference("binding"),
                        ]
                    ),
                    definitions: [
                        .init(
                            name: "binding",
                            specification: .sequence(
                                [
                                    .identifier,
                                    .literal("="),
                                    .identifier,
                                ]
                            )
                        ),
                    ]
                )
                let parser = try grammar.compile()
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "matching",
                        text: "let name=value"
                    ),
                    SearchDocument(
                        id: "missing-equals",
                        text: "let name value"
                    ),
                    SearchDocument(
                        id: "missing-let",
                        text: "name=value"
                    )
                )
                let frontier = StructuralSearch.frontier(
                    in: corpus,
                    with: parser
                )

                try Expect.equal(
                    parser.requiredAnchors,
                    [
                        .literal("let "),
                        .literal("="),
                    ],
                    "Search consumes Parsing's resolved compiled required-anchor facts"
                )
                try Expect.equal(
                    frontier.candidates.map(\.documentID),
                    [
                        "matching",
                    ],
                    "all Parsing-required literals participate in document admission"
                )

                let proof = try StructuralSearch.prove(
                    in: corpus,
                    with: parser
                )

                try Expect.equal(
                    proof.proofs.map(\.documentID),
                    [
                        "matching",
                    ],
                    "compiled grammar proof reuses the preselected frontier without reinterpreting grammar semantics"
                )
            }

            Test(
                "zero-accepting cardinality preserves candidates that lack required anchors"
            ) {
                let corpus = SearchCorpus(
                    SearchDocument(
                        id: "matching",
                        text: "needle"
                    ),
                    SearchDocument(
                        id: "missing",
                        text: "other"
                    )
                )
                let specification = StructuredParser.Specification.literal(
                    "needle"
                )
                let proof = try StructuralSearch.prove(
                    in: corpus,
                    with: specification,
                    requiring: .atMost(0)
                )

                try Expect.equal(
                    proof.candidateCount,
                    2,
                    "cardinality that accepts zero matches must evaluate the full corpus"
                )
                try Expect.equal(
                    proof.proofs.map(\.documentID),
                    [
                        "missing",
                    ],
                    "candidate without the required literal can satisfy a zero-match structural proof"
                )
                try Expect.equal(
                    proof.matchCount,
                    0,
                    "accepted zero-match proof preserves structural cardinality semantics"
                )
            }
        }
    }
}
