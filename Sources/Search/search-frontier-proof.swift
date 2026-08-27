import Parsing
import Position

public extension SearchFrontier {
    func prove(
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

    func prove(
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
}

private extension SearchFrontier {
    struct ProofRegion {
        let text: String
        let startOffset: Int
    }

    func prove(
        in corpus: SearchCorpus<ID>,
        with parser: StructuredParser.Compiled,
        requiring cardinality: StructuredParser.Cardinality
    ) throws -> SearchProofResult<ID> {
        try validate(
            cardinality
        )

        var proofs: [SearchProof<ID>] = []

        for candidate in candidates {
            guard
                let document = corpus.documents.first(
                    where: {
                        $0.id == candidate.documentID
                    }
                ),
                let region = proofRegion(
                    for: candidate,
                    in: document.text
                )
            else {
                continue
            }

            let matches = parser.matches(
                in: region.text
            )
            .map {
                rebased(
                    $0,
                    by: region.startOffset
                )
            }

            guard cardinality.accepts(
                matches.count
            ) else {
                continue
            }

            proofs.append(
                SearchProof(
                    candidate: candidate,
                    matches: matches
                )
            )
        }

        return SearchProofResult(
            candidateCount: candidates.count,
            proofs: proofs
        )
    }

    func validate(
        _ cardinality: StructuredParser.Cardinality
    ) throws {
        let count: Int

        switch cardinality {
        case .exactly(let value),
             .atLeast(let value),
             .atMost(let value):
            count = value
        }

        guard count >= 0 else {
            throw StructuredParser.CardinalityError.invalid(
                cardinality
            )
        }
    }

    func proofRegion(
        for candidate: SearchCandidate<ID>,
        in text: String
    ) -> ProofRegion? {
        guard
            candidate.lineRange.start >= 1,
            candidate.lineRange.end >= candidate.lineRange.start
        else {
            return nil
        }

        var start = text.startIndex
        var currentLine = 1

        while currentLine < candidate.lineRange.start {
            guard let newline = text[start...].firstIndex(
                of: "\n"
            ) else {
                return nil
            }

            start = text.index(
                after: newline
            )
            currentLine += 1
        }

        var end = start
        var endingLine = currentLine

        while endingLine <= candidate.lineRange.end {
            guard let newline = text[end...].firstIndex(
                of: "\n"
            ) else {
                end = text.endIndex
                break
            }

            end = text.index(
                after: newline
            )
            endingLine += 1
        }

        return ProofRegion(
            text: String(
                text[start..<end]
            ),
            startOffset: text.distance(
                from: text.startIndex,
                to: start
            )
        )
    }

    func rebased(
        _ match: StructuredParser.Match,
        by offset: Int
    ) -> StructuredParser.Match {
        StructuredParser.Match(
            range: rebased(
                match.range,
                by: offset
            ),
            captures: match.captures.map {
                StructuredParser.Capture(
                    name: $0.name,
                    value: $0.value,
                    range: rebased(
                        $0.range,
                        by: offset
                    )
                )
            }
        )
    }

    func rebased(
        _ range: PositionRange,
        by offset: Int
    ) -> PositionRange {
        PositionRange(
            uncheckedStart: PositionIndex(
                range.start.offset + offset
            ),
            uncheckedEnd: PositionIndex(
                range.end.offset + offset
            )
        )
    }
}
