import Matching
import Search
import TestFlows

extension SearchFlowSuite {
    static var completenessModeFlow: TestFlow {
        TestFlow(
            "search-completeness-modes",
            tags: [
                "search",
                "completeness",
                "ranked",
                "exhaustive",
                "delivery",
            ]
        ) {
            let corpus = SearchCorpus(
                SearchDocument(
                    id: "dominant",
                    text: """
                    alpha
                    one
                    two
                    three
                    omega
                    """
                ),
                SearchDocument(
                    id: "secondary",
                    text: "alpha"
                )
            )
            let queries = [
                SearchQuery(
                    "alpha",
                    id: "alpha"
                ),
                SearchQuery(
                    "omega",
                    id: "omega"
                ),
            ]

            Step(
                "ranked search sees the complete admitted document universe before frontier delivery"
            ) {
                let result = TextSearch.search(
                    queries,
                    in: corpus,
                    options: SearchOptions(
                        mode: .ranked,
                        strategy: .contains,
                        caseSensitive: true,
                        minimumScore: 1,
                        maximumResults: nil
                    )
                )

                try Expect.equal(
                    result.matchedDocumentCount,
                    2,
                    "ranked matched document count"
                )
                try Expect.equal(
                    result.returnedHitCount,
                    2,
                    "ranked complete hit count"
                )
                try Expect.equal(
                    result.truncated,
                    false,
                    "ranked document universe is complete"
                )

                let full = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: nil,
                        maximumCandidatesPerDocument: 1
                    )
                )
                let bounded = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 1,
                        maximumCandidatesPerDocument: 1
                    )
                )

                try Expect.equal(
                    full.discoveredCandidateCount,
                    3,
                    "ranked discovered candidate count"
                )
                try Expect.equal(
                    full.totalCandidateCount,
                    2,
                    "ranked diversity-selected candidate universe"
                )
                try Expect.equal(
                    full.candidates.map(\.documentID),
                    [
                        "dominant",
                        "secondary",
                    ],
                    "ranked diversity preserves multiple documents"
                )
                try Expect.equal(
                    bounded.totalCandidateCount,
                    full.totalCandidateCount,
                    "ranked delivery bound does not change total candidate count"
                )
                try Expect.equal(
                    bounded.returnedCandidateCount,
                    1,
                    "ranked delivery bound limits serialized candidates"
                )
                try Expect.equal(
                    bounded.truncated,
                    true,
                    "ranked bounded delivery is explicit"
                )
                try Expect.equal(
                    bounded.hasMore,
                    true,
                    "ranked bounded delivery reports more candidates"
                )
            }

            Step(
                "exhaustive search preserves every candidate region and ignores diversity suppression"
            ) {
                let result = TextSearch.search(
                    queries,
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        strategy: .contains,
                        caseSensitive: true,
                        minimumScore: 1,
                        maximumResults: nil
                    )
                )
                let full = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: nil,
                        maximumCandidatesPerDocument: 1
                    )
                )
                let bounded = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2,
                        maximumCandidatesPerDocument: 1
                    )
                )

                try Expect.equal(
                    result.hits.map(\.documentID),
                    [
                        "dominant",
                        "secondary",
                    ],
                    "exhaustive document order is deterministic"
                )
                try Expect.equal(
                    full.discoveredCandidateCount,
                    3,
                    "exhaustive discovered candidate count"
                )
                try Expect.equal(
                    full.totalCandidateCount,
                    3,
                    "exhaustive retains all candidate regions"
                )
                try Expect.equal(
                    full.candidates.map(\.documentID),
                    [
                        "dominant",
                        "dominant",
                        "secondary",
                    ],
                    "exhaustive keeps repeated regions from one document"
                )
                try Expect.equal(
                    bounded.totalCandidateCount,
                    3,
                    "exhaustive delivery bound preserves total count"
                )
                try Expect.equal(
                    bounded.candidates.map(\.documentID),
                    [
                        "dominant",
                        "dominant",
                    ],
                    "exhaustive ignores per-document diversity suppression"
                )
                try Expect.equal(
                    bounded.returnedCandidateCount,
                    2,
                    "exhaustive delivery is independently bounded"
                )
                try Expect.equal(
                    bounded.hasMore,
                    true,
                    "exhaustive bounded delivery reports more candidates"
                )
            }

            Step(
                "frontier pagination slices the deterministic semantic candidate universe"
            ) {
                let rankedResult = TextSearch.search(
                    queries,
                    in: corpus,
                    options: SearchOptions(
                        mode: .ranked,
                        strategy: .contains,
                        caseSensitive: true,
                        minimumScore: 1,
                        maximumResults: nil
                    )
                )
                let rankedFull = rankedResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: nil,
                        maximumCandidatesPerDocument: 1
                    )
                )
                let rankedFirst = rankedResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 1,
                        maximumCandidatesPerDocument: 1,
                        offset: 0
                    )
                )
                let rankedSecond = rankedResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 1,
                        maximumCandidatesPerDocument: 1,
                        offset: 1
                    )
                )

                try Expect.equal(
                    rankedFirst.candidates.map(\.documentID),
                    [
                        "dominant",
                    ],
                    "ranked first page preserves semantic ordering"
                )
                try Expect.equal(
                    rankedFirst.nextOffset ?? -1,
                    1,
                    "ranked first page exposes continuation offset"
                )
                try Expect.equal(
                    rankedFirst.hasMore,
                    true,
                    "ranked first page reports a later page"
                )
                try Expect.equal(
                    rankedSecond.candidates.map(\.documentID),
                    [
                        "secondary",
                    ],
                    "ranked second page resumes after the first page"
                )
                try Expect.equal(
                    rankedSecond.nextOffset == nil,
                    true,
                    "ranked final page has no continuation offset"
                )
                try Expect.equal(
                    rankedSecond.hasMore,
                    false,
                    "ranked final page reports no later page"
                )
                try Expect.equal(
                    rankedSecond.truncated,
                    true,
                    "ranked final continuation page remains a partial response"
                )
                try Expect.equal(
                    rankedFirst.discoveredCandidateCount,
                    rankedSecond.discoveredCandidateCount,
                    "ranked discovered candidate count is stable across pages"
                )
                try Expect.equal(
                    rankedFirst.totalCandidateCount,
                    rankedSecond.totalCandidateCount,
                    "ranked semantic candidate count is stable across pages"
                )
                try Expect.equal(
                    rankedFirst.candidates.map(\.documentID)
                        + rankedSecond.candidates.map(\.documentID),
                    rankedFull.candidates.map(\.documentID),
                    "ranked pages reconstruct the full semantic universe"
                )

                let exhaustiveResult = TextSearch.search(
                    queries,
                    in: corpus,
                    options: SearchOptions(
                        mode: .exhaustive,
                        strategy: .contains,
                        caseSensitive: true,
                        minimumScore: 1,
                        maximumResults: nil
                    )
                )
                let exhaustiveFull = exhaustiveResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: nil,
                        maximumCandidatesPerDocument: 1
                    )
                )
                let exhaustiveFirst = exhaustiveResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2,
                        maximumCandidatesPerDocument: 1,
                        offset: 0
                    )
                )
                let exhaustiveSecond = exhaustiveResult.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: 2,
                        maximumCandidatesPerDocument: 1,
                        offset: 2
                    )
                )

                try Expect.equal(
                    exhaustiveFirst.candidates.map(\.documentID),
                    [
                        "dominant",
                        "dominant",
                    ],
                    "exhaustive first page retains repeated source regions"
                )
                try Expect.equal(
                    exhaustiveFirst.nextOffset ?? -1,
                    2,
                    "exhaustive first page exposes continuation offset"
                )
                try Expect.equal(
                    exhaustiveSecond.candidates.map(\.documentID),
                    [
                        "secondary",
                    ],
                    "exhaustive second page resumes after two regions"
                )
                try Expect.equal(
                    exhaustiveSecond.hasMore,
                    false,
                    "exhaustive final page reports no later page"
                )
                try Expect.equal(
                    exhaustiveSecond.nextOffset == nil,
                    true,
                    "exhaustive final page has no continuation offset"
                )
                try Expect.equal(
                    exhaustiveSecond.truncated,
                    true,
                    "exhaustive final continuation page remains a partial response"
                )
                try Expect.equal(
                    exhaustiveFirst.candidates.map(\.documentID)
                        + exhaustiveSecond.candidates.map(\.documentID),
                    exhaustiveFull.candidates.map(\.documentID),
                    "exhaustive pages reconstruct the full semantic universe"
                )
            }

            Step(
                "direct SearchResult hit delivery reports upstream truncation explicitly"
            ) {
                let result = TextSearch.search(
                    queries,
                    in: corpus,
                    options: SearchOptions(
                        mode: .ranked,
                        strategy: .contains,
                        caseSensitive: true,
                        minimumScore: 1,
                        maximumResults: 1
                    )
                )
                let frontier = result.frontier(
                    options: SearchFrontierOptions(
                        mergeDistanceLines: 0,
                        maximumCandidates: nil,
                        maximumCandidatesPerDocument: nil
                    )
                )

                try Expect.equal(
                    result.matchedDocumentCount,
                    2,
                    "direct search matched document count"
                )
                try Expect.equal(
                    result.returnedHitCount,
                    1,
                    "direct search returned hit count"
                )
                try Expect.equal(
                    result.truncated,
                    true,
                    "direct hit delivery truncation is explicit"
                )
                try Expect.equal(
                    frontier.searchWasTruncated,
                    true,
                    "frontier preserves upstream search truncation"
                )
                try Expect.equal(
                    frontier.truncated,
                    true,
                    "frontier never claims completeness after truncated input"
                )
            }
        }
    }
}
