import Foundation
import Fuzzy
import Matching
import Position
import Ranking
import Tokens

public enum TextSearch {
    public static func search<ID: Hashable & Sendable>(
        _ text: String,
        in corpus: SearchCorpus<ID>,
        options: SearchOptions = .defaults
    ) -> SearchResult<ID> {
        search(
            SearchQuery(
                text
            ),
            in: corpus,
            options: options
        )
    }

    public static func search<ID: Hashable & Sendable>(
        _ query: SearchQuery,
        in corpus: SearchCorpus<ID>,
        options: SearchOptions = .defaults
    ) -> SearchResult<ID> {
        search(
            [
                query,
            ],
            in: corpus,
            options: options
        )
    }

    public static func search<ID: Hashable & Sendable>(
        _ queries: [SearchQuery],
        in corpus: SearchCorpus<ID>,
        options: SearchOptions = .defaults
    ) -> SearchResult<ID> {
        let queries = queries.filter {
            !$0.isEmpty
        }

        var accumulators = corpus.documents
            .enumerated()
            .map { element in
                TextSearchAccumulator(
                    documentID: element.element.id,
                    sourceOrder: element.offset
                )
            }

        for query in queries {
            let matchQuery = MatchQuery(
                query.text,
                options: normalization(
                    for: options
                )
            )

            for (
                index,
                document
            ) in corpus.documents.enumerated() {
                let result = match(
                    matchQuery,
                    against: document,
                    options: options
                )

                guard result.didMatch else {
                    continue
                }

                let score = rankingScore(
                    from: result.score,
                    query: query
                )

                let spans = resolvedSpans(
                    for: result,
                    query: matchQuery,
                    document: document,
                    options: options
                )

                accumulators[index].append(
                    SearchEvidence(
                        queryID: query.id,
                        query: query.text,
                        strategy: options.strategy,
                        score: score,
                        spans: spans
                    )
                )
            }
        }

        let candidates = accumulators
            .filter(\.didMatch)
            .map { accumulator in
                let score = accumulator.score
                let hit = SearchHit(
                    documentID: accumulator.documentID,
                    score: score,
                    evidence: accumulator.evidence
                )

                return Ranked(
                    value: hit,
                    score: score,
                    sourceOrder: accumulator.sourceOrder
                )
            }

        let selection = selection(
            for: options
        )
        let admitted = candidates.filter {
            selection.threshold.contains(
                $0.score
            )
        }
        let selected: [Ranked<SearchHit<ID>>]

        switch options.mode {
        case .ranked:
            selected = Ranking.select(
                candidates,
                options: selection
            )

        case .exhaustive:
            let ordered = admitted.sorted { lhs, rhs in
                let lhsOrder = lhs.sourceOrder ?? Int.max
                let rhsOrder = rhs.sourceOrder ?? Int.max

                return lhsOrder < rhsOrder
            }

            if let maximumResults = selection.limit {
                selected = Array(
                    ordered.prefix(
                        maximumResults
                    )
                )
            } else {
                selected = ordered
            }
        }

        return SearchResult(
            mode: options.mode,
            queries: queries,
            searchedDocumentCount: corpus.count,
            matchedDocumentCount: admitted.count,
            hits: selected.map(\.value)
        )
    }
}

private extension TextSearch {
    static func match<ID: Hashable & Sendable>(
        _ query: MatchQuery,
        against document: SearchDocument<ID>,
        options: SearchOptions
    ) -> MatchResult<ID> {
        switch options.strategy {
        case .exact:
            return ExactMatcher<SearchDocument<ID>>()
                .match(
                    query: query,
                    against: document
                )

        case .prefix:
            return PrefixMatcher<SearchDocument<ID>>()
                .match(
                    query: query,
                    against: document
                )

        case .contains:
            return ContainsMatcher<SearchDocument<ID>>()
                .match(
                    query: query,
                    against: document
                )

        case .subsequence:
            return SubsequenceMatcher<SearchDocument<ID>>()
                .match(
                    query: query,
                    against: document
                )

        case .fuzzy:
            return FuzzyMatcher<SearchDocument<ID>>()
                .match(
                    query: query,
                    against: document
                )
        }
    }

    static func normalization(
        for options: SearchOptions
    ) -> TokenNormalizationOptions {
        TokenNormalizationOptions(
            case: TokenCaseOptions(
                sensitivity: options.caseSensitive
                    ? .sensitive
                    : .insensitive
            )
        )
    }

    static func selection(
        for options: SearchOptions
    ) -> RankingSelectionOptions {
        let threshold: RankingThreshold

        if let minimumScore = options.minimumScore {
            threshold = .minimum(
                minimumScore
            )
        } else {
            threshold = .none
        }

        return RankingSelectionOptions(
            order: .descending,
            threshold: threshold,
            limit: options.maximumResults
        )
    }

    static func rankingScore(
        from score: MatchScore,
        query: SearchQuery
    ) -> RankingScore {
        let value = score.value * query.weight

        var components = score.components.map { component in
            RankingScoreComponent(
                name: component.name,
                value: component.value,
                detail: component.detail
            )
        }

        if query.weight != 1 {
            components.append(
                RankingScoreComponent(
                    name: "queryWeight",
                    value: value - score.value,
                    detail: "\(query.weight)x \(query.text)"
                )
            )
        }

        return RankingScore(
            value: value,
            components: components
        )
    }

    static func resolvedSpans<ID: Hashable & Sendable>(
        for result: MatchResult<ID>,
        query: MatchQuery,
        document: SearchDocument<ID>,
        options: SearchOptions
    ) -> [SearchSpan] {
        if options.strategy == .contains {
            return containsSpans(
                query.normalized,
                in: document.text,
                caseSensitive: options.caseSensitive
            )
        }

        return result.fieldResults
            .filter {
                $0.field.name == "text"
            }
            .flatMap { fieldResult in
                MatchPositionResolver.lineSpans(
                    for: fieldResult,
                    in: document.text
                )
                .map { span in
                    SearchSpan(
                        range: PositionRange(
                            uncheckedStart: PositionIndex(
                                span.matchRange.startOffset
                            ),
                            uncheckedEnd: PositionIndex(
                                span.matchRange.endOffset
                            )
                        ),
                        lineRange: span.lineRange
                    )
                }
            }
    }

    static func containsSpans(
        _ query: String,
        in text: String,
        caseSensitive: Bool
    ) -> [SearchSpan] {
        guard !query.isEmpty else {
            return []
        }

        let compareOptions: String.CompareOptions = caseSensitive
            ? []
            : [.caseInsensitive]

        var spans: [SearchSpan] = []
        var start = text.startIndex
        let lineTable = LineTable(
            text: text
        )

        while start < text.endIndex,
              let range = text.range(
                  of: query,
                  options: compareOptions,
                  range: start..<text.endIndex
              )
        {
            let startOffset = text.distance(
                from: text.startIndex,
                to: range.lowerBound
            )

            let endOffset = text.distance(
                from: text.startIndex,
                to: range.upperBound
            )

            let positionRange = PositionRange(
                uncheckedStart: PositionIndex(
                    startOffset
                ),
                uncheckedEnd: PositionIndex(
                    endOffset
                )
            )

            spans.append(
                SearchSpan(
                    range: positionRange,
                    lineRange: lineRange(
                        for: positionRange,
                        table: lineTable
                    )
                )
            )

            start = range.upperBound
        }

        return spans
    }

    static func lineRange(
        for range: PositionRange,
        table: LineTable
    ) -> LineRange {
        let start = table.lineAndColumn(
            at: range.start.offset
        )

        let inclusiveEndOffset = range.isEmpty
            ? range.start.offset
            : max(
                range.start.offset,
                range.end.offset - 1
            )

        let end = table.lineAndColumn(
            at: inclusiveEndOffset
        )

        return LineRange(
            uncheckedStart: start.line,
            uncheckedEnd: end.line
        )
    }
}

private struct TextSearchAccumulator<ID: Hashable & Sendable>:
    Sendable
{
    let documentID: ID
    let sourceOrder: Int
    var evidence: [SearchEvidence] = []

    var didMatch: Bool {
        !evidence.isEmpty
    }

    var score: RankingScore {
        RankingScore(
            value: evidence.reduce(
                into: 0
            ) { partial, evidence in
                partial += evidence.score.value
            },
            components: evidence.flatMap {
                $0.score.components
            }
        )
    }

    mutating func append(
        _ evidence: SearchEvidence
    ) {
        self.evidence.append(
            evidence
        )
    }
}
