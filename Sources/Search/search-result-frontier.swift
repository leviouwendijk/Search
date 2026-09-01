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
            let requiresRequiredAnchor = hit.evidence.contains { evidence in
                evidence.role == .required
            }
            let accumulators = coalesced(
                seeds,
                mergeDistanceLines: options.mergeDistanceLines
            ).filter { accumulator in
                !requiresRequiredAnchor
                    || accumulator.evidence.contains { evidence in
                        evidence.role == .required
                    }
            }

            for accumulator in accumulators {
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

        let semanticCandidates: [Ranked<SearchCandidate<ID>>]

        switch mode {
        case .ranked:
            let ranked = Ranking.select(
                candidates,
                options: RankingSelectionOptions(
                    order: .descending,
                    threshold: .none,
                    limit: nil
                )
            )

            semanticCandidates = diversified(
                ranked,
                maximumCandidates: nil,
                maximumCandidatesPerDocument: options.maximumCandidatesPerDocument
            )

        case .exhaustive:
            semanticCandidates = candidates.sorted { lhs, rhs in
                let lhsOrder = lhs.sourceOrder ?? Int.max
                let rhsOrder = rhs.sourceOrder ?? Int.max

                if lhsOrder != rhsOrder {
                    return lhsOrder < rhsOrder
                }

                if lhs.value.lineRange.start != rhs.value.lineRange.start {
                    return lhs.value.lineRange.start < rhs.value.lineRange.start
                }

                return lhs.value.lineRange.end < rhs.value.lineRange.end
            }
        }

        let pageStart = min(
            options.offset,
            semanticCandidates.count
        )
        let page = semanticCandidates.dropFirst(
            pageStart
        )
        let selected: [Ranked<SearchCandidate<ID>>]

        if let maximumCandidates = options.maximumCandidates {
            selected = Array(
                page.prefix(
                    maximumCandidates
                )
            )
        } else {
            selected = Array(
                page
            )
        }

    func diversified(
        _ candidates: [Ranked<SearchCandidate<ID>>],
        maximumCandidates: Int?,
        maximumCandidatesPerDocument: Int?
    ) -> [Ranked<SearchCandidate<ID>>] {
        var selected: [Ranked<SearchCandidate<ID>>] = []
        var documentCounts: [ID: Int] = [:]

        for candidate in candidates {
            if let maximumCandidates,
               selected.count >= maximumCandidates
            {
                break
            }

            if let maximumCandidatesPerDocument {
                let count = documentCounts[
                    candidate.value.documentID,
                    default: 0
                ]

                guard count < maximumCandidatesPerDocument else {
                    continue
                }

                documentCounts[candidate.value.documentID] = count + 1
            }

            selected.append(
                candidate
            )
        }

        return selected
    }

        return SearchFrontier(
            mode: mode,
            matchedDocumentCount: matchedDocumentCount,
            searchedHitCount: returnedHitCount,
            discoveredCandidateCount: candidates.count,
            totalCandidateCount: semanticCandidates.count,
            offset: options.offset,
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
        let role: SearchProbeRole
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
                            role: evidence.role,
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
                role: item.role,
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
                role: existing.role,
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
