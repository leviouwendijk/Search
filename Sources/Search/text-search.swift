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
        search(
            probes: queries.map { query in
                SearchProbe(
                    query,
                    role: .preferred,
                    strategy: options.strategy
                )
            },
            in: corpus,
            options: options
        )
    }

    public static func search<ID: Hashable & Sendable>(
        probes: [SearchProbe],
        in corpus: SearchCorpus<ID>,
        options: SearchOptions = .defaults
    ) -> SearchResult<ID> {
        search(
            probes: probes,
            in: corpus.documents,
            options: options
        )
    }

    /// Searches any source's candidates across their fields; a probe with a
    /// `field` matches that field only.
    public static func search<Source: CandidateSource>(
        probes: [SearchProbe],
        in source: Source,
        options: SearchOptions = .defaults
    ) -> SearchResult<Source.Candidate.MatchID> {
        search(
            probes: probes,
            in: source.candidates(),
            options: options
        )
    }

    public static func search<Candidate: MatchCandidate>(
        probes: [SearchProbe],
        in candidates: [Candidate],
        options: SearchOptions = .defaults
    ) -> SearchResult<Candidate.MatchID> {
        let probes = probes.filter {
            !$0.isEmpty
        }
        let requiredProbeCount = probes.reduce(
            into: 0
        ) { count, probe in
            if probe.role == .required {
                count += 1
            }
        }

        var accumulators = candidates
            .enumerated()
            .map { element in
                TextSearchAccumulator(
                    documentID: element.element.matchID,
                    sourceOrder: element.offset
                )
            }

        for (probeIndex, probe) in probes.enumerated() {
            let query = probe.query
            let matchQuery = MatchQuery(
                query.text,
                options: normalization(
                    for: options
                )
            )

            for (
                index,
                document
            ) in candidates.enumerated() {
                let result = probe.field.map { field in
                    match(
                        matchQuery,
                        against: FieldScopedCandidate(document, field: field),
                        strategy: probe.strategy,
                        options: options
                    )
                } ?? match(
                    matchQuery,
                    against: document,
                    strategy: probe.strategy,
                    options: options
                )

                guard result.didMatch else {
                    continue
                }

                switch probe.role {
                case .excluded:
                    accumulators[index].markExcluded()

                case .required,
                     .preferred:
                    let score = rankingScore(
                        from: result.score,
                        query: query
                    )

                    let spans = resolvedSpans(
                        for: result
                    )

                    accumulators[index].append(
                        SearchEvidence(
                            queryID: query.id,
                            query: query.text,
                            role: probe.role,
                            strategy: probe.strategy,
                            score: score,
                            spans: spans
                        )
                    )

                    if probe.role == .required {
                        accumulators[index].markRequired(
                            probeIndex
                        )
                    }
                }
            }
        }

        let candidates = accumulators
            .filter {
                $0.isAdmitted(
                    requiredProbeCount: requiredProbeCount
                )
            }
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
        let selected: [Ranked<SearchHit<Candidate.MatchID>>]

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
            probes: probes,
            searchedDocumentCount: candidates.count,
            matchedDocumentCount: admitted.count,
            hits: selected.map(\.value)
        )
    }
}

private extension TextSearch {
    static func match<Candidate: MatchCandidate>(
        _ query: MatchQuery,
        against document: Candidate,
        strategy: SearchStrategy,
        options: SearchOptions
    ) -> MatchResult<Candidate.MatchID> {
        switch strategy {
        case .exact:
            return ExactMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .prefix:
            return PrefixMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .contains:
            return ContainsMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .identifier:
            return IdentifierMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .subsequence:
            return SubsequenceMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .fuzzy:
            return FuzzyMatcher<Candidate>()
                .match(
                    query: query,
                    against: document
                )

        case .regex:
            return RegexMatcher<Candidate>()
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
        for result: MatchResult<ID>
    ) -> [SearchSpan] {
        return result.fieldResults
            .flatMap { fieldResult in
                MatchPositionResolver.lineSpans(
                    for: fieldResult,
                    in: fieldResult.field.text
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
                        lineRange: span.lineRange,
                        field: fieldResult.field.name
                    )
                }
            }
    }

}

private struct TextSearchAccumulator<ID: Hashable & Sendable>:
    Sendable
{
    let documentID: ID
    let sourceOrder: Int
    var evidence: [SearchEvidence] = []
    var matchedRequiredProbeIndices: Set<Int> = []
    var matchedExcludedProbe = false

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

    func isAdmitted(
        requiredProbeCount: Int
    ) -> Bool {
        !matchedExcludedProbe
            && matchedRequiredProbeIndices.count == requiredProbeCount
            && didMatch
    }

    mutating func append(
        _ evidence: SearchEvidence
    ) {
        self.evidence.append(
            evidence
        )
    }

    mutating func markRequired(
        _ probeIndex: Int
    ) {
        matchedRequiredProbeIndices.insert(
            probeIndex
        )
    }

    mutating func markExcluded() {
        matchedExcludedProbe = true
    }
}
