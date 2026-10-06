import Parsing
import Position
import Ranking

public enum StructuralSearch {
    public static func frontier<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with specification: StructuredParser.Specification
    ) throws -> SearchFrontier<ID> {
        try frontier(
            in: corpus,
            with: specification.compile()
        )
    }

    public static func frontier<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with grammar: StructuredParser.Grammar
    ) throws -> SearchFrontier<ID> {
        try frontier(
            in: corpus,
            with: grammar.compile()
        )
    }

    public static func frontier<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with parser: StructuredParser.Compiled
    ) -> SearchFrontier<ID> {
        let anchors = usableLiteralAnchors(
            parser.requiredAnchors
        )

        guard !anchors.isEmpty else {
            return fullDocumentFrontier(
                corpus
            )
        }

        let result = TextSearch.search(
            probes: anchors.map { anchor in
                SearchProbe(
                    anchor,
                    role: .required,
                    strategy: .contains
                )
            },
            in: corpus,
            options: SearchOptions(
                mode: .exhaustive,
                strategy: .contains,
                caseSensitive: true,
                minimumScore: nil,
                maximumResults: nil
            )
        )
        let candidates: [SearchCandidate<ID>] = result.hits.compactMap { hit in
            guard let document = corpus.documents.first(
                where: {
                    $0.id == hit.documentID
                }
            ) else {
                return nil
            }

            return SearchCandidate(
                documentID: hit.documentID,
                lineRange: fullLineRange(
                    document.text
                ),
                score: hit.score,
                evidence: hit.evidence
            )
        }

        return SearchFrontier(
            mode: .exhaustive,
            matchedDocumentCount: result.matchedDocumentCount,
            searchedHitCount: result.hits.count,
            discoveredCandidateCount: candidates.count,
            totalCandidateCount: candidates.count,
            candidates: candidates
        )
    }

    public static func prove<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with specification: StructuredParser.Specification,
        requiring cardinality: StructuredParser.Cardinality = .atLeast(1)
    ) throws -> SearchProofResult<ID> {
        try prove(
            in: corpus,
            with: specification.compile(),
            requiring: cardinality
        )
    }

    public static func prove<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with grammar: StructuredParser.Grammar,
        requiring cardinality: StructuredParser.Cardinality = .atLeast(1)
    ) throws -> SearchProofResult<ID> {
        try prove(
            in: corpus,
            with: grammar.compile(),
            requiring: cardinality
        )
    }

    public static func prove<ID: Hashable & Sendable>(
        in corpus: SearchCorpus<ID>,
        with parser: StructuredParser.Compiled,
        requiring cardinality: StructuredParser.Cardinality = .atLeast(1)
    ) throws -> SearchProofResult<ID> {
        try frontier(
            in: corpus,
            with: parser
        ).prove(
            in: corpus,
            with: parser,
            requiring: cardinality
        )
    }
}

private extension StructuralSearch {
    static func usableLiteralAnchors(
        _ anchors: [StructuredParser.RequiredAnchor]
    ) -> [String] {
        anchors.compactMap { anchor in
            switch anchor {
            case .literal(let value):
                guard !value.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty else {
                    return nil
                }

                return value
            }
        }
    }

    static func fullDocumentFrontier<ID: Hashable & Sendable>(
        _ corpus: SearchCorpus<ID>
    ) -> SearchFrontier<ID> {
        let candidates = corpus.documents.map { document in
            SearchCandidate(
                documentID: document.id,
                lineRange: fullLineRange(
                    document.text
                ),
                score: RankingScore(
                    value: 0,
                    components: []
                ),
                evidence: []
            )
        }

        return SearchFrontier(
            mode: .exhaustive,
            matchedDocumentCount: corpus.count,
            searchedHitCount: corpus.count,
            discoveredCandidateCount: candidates.count,
            totalCandidateCount: candidates.count,
            candidates: candidates
        )
    }

    static func fullLineRange(
        _ text: String
    ) -> LineRange {
        let lineCount = text.reduce(
            into: 1
        ) { count, character in
            if character == "\n" {
                count += 1
            }
        }

        return LineRange(
            uncheckedStart: 1,
            uncheckedEnd: lineCount
        )
    }
}
