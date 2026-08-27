import Position
import Ranking

public extension SearchResult {
    func frontier(
        options: SearchFrontierOptions = .defaults
    ) -> SearchFrontier<ID> {
        var candidates: [Ranked<SearchCandidate<ID>>] = []
        var sourceOrder = 0

        for hit in hits {
            let seeds = frontierSeeds(
                for: hit
            )

            for accumulator in coalesced(
                seeds,
                mergeDistanceLines: options.mergeDistanceLines
            ) {
                let evidence = mergedEvidence(
                    accumulator.evidence
                )
                let score = frontierScore(
                    evidence
                )

                candidates.append(
                    Ranked(
                        value: SearchCandidate(
                            documentID: hit.documentID,
                            lineRange: accumulator.lineRange,
                            score: score,
                            evidence: evidence
                        ),
                        score: score,
                        sourceOrder: sourceOrder
                    )
                )

                sourceOrder += 1
            }
        }

        let selected = Ranking.select(
            candidates,
            options: RankingSelectionOptions(
                order: .descending,
                threshold: .none,
                limit: options.maximumCandidates
            )
        )

        return SearchFrontier(
            candidates: selected.map(\.value)
        )
    }
}

private extension SearchResult {
    struct FrontierSeed {
        let lineRange: LineRange
        let evidence: SearchEvidence
    }

    struct FrontierAccumulator {
        var lineRange: LineRange
        var evidence: [SearchEvidence]
    }

    struct EvidenceKey: Hashable {
        let queryID: String?
        let query: String
        let strategy: SearchStrategy
    }

    func frontierSeeds(
        for hit: SearchHit<ID>
    ) -> [FrontierSeed] {
        hit.evidence
            .flatMap { evidence in
                evidence.spans.map { span in
                    FrontierSeed(
                        lineRange: span.lineRange,
                        evidence: SearchEvidence(
                            queryID: evidence.queryID,
                            query: evidence.query,
                            strategy: evidence.strategy,
                            score: evidence.score,
                            spans: [
                                span,
                            ]
                        )
                    )
                }
            }
            .sorted { lhs, rhs in
                if lhs.lineRange.start != rhs.lineRange.start {
                    return lhs.lineRange.start < rhs.lineRange.start
                }

                return lhs.lineRange.end < rhs.lineRange.end
            }
    }

    func coalesced(
        _ seeds: [FrontierSeed],
        mergeDistanceLines: Int
    ) -> [FrontierAccumulator] {
        var result: [FrontierAccumulator] = []

        for seed in seeds {
            guard var last = result.popLast() else {
                result.append(
                    FrontierAccumulator(
                        lineRange: seed.lineRange,
                        evidence: [
                            seed.evidence,
                        ]
                    )
                )
                continue
            }

            let mergeLimit = last.lineRange.end
                + mergeDistanceLines
                + 1

            guard seed.lineRange.start <= mergeLimit else {
                result.append(
                    last
                )
                result.append(
                    FrontierAccumulator(
                        lineRange: seed.lineRange,
                        evidence: [
                            seed.evidence,
                        ]
                    )
                )
                continue
            }

            last.lineRange = LineRange(
                uncheckedStart: min(
                    last.lineRange.start,
                    seed.lineRange.start
                ),
                uncheckedEnd: max(
                    last.lineRange.end,
                    seed.lineRange.end
                )
            )

            last.evidence.append(
                seed.evidence
            )

            result.append(
                last
            )
        }

        return result
    }

    func mergedEvidence(
        _ evidence: [SearchEvidence]
    ) -> [SearchEvidence] {
        var order: [EvidenceKey] = []
        var values: [EvidenceKey: SearchEvidence] = [:]

        for item in evidence {
            let key = EvidenceKey(
                queryID: item.queryID,
                query: item.query,
                strategy: item.strategy
            )

            guard let existing = values[key] else {
                order.append(
                    key
                )
                values[key] = item
                continue
            }

            values[key] = SearchEvidence(
                queryID: existing.queryID,
                query: existing.query,
                strategy: existing.strategy,
                score: existing.score,
                spans: (existing.spans + item.spans)
                    .sorted { lhs, rhs in
                        if lhs.range.start.offset
                            != rhs.range.start.offset
                        {
                            return lhs.range.start.offset
                                < rhs.range.start.offset
                        }

                        return lhs.range.end.offset
                            < rhs.range.end.offset
                    }
            )
        }

        return order.compactMap {
            values[$0]
        }
    }

    func frontierScore(
        _ evidence: [SearchEvidence]
    ) -> RankingScore {
        RankingScore(
            value: evidence.reduce(
                into: 0
            ) { partial, item in
                partial += item.score.value
            },
            components: evidence.flatMap {
                $0.score.components
            }
        )
    }
}
