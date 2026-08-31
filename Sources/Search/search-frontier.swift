public struct SearchFrontier<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let mode: SearchMode
    public let matchedDocumentCount: Int
    public let searchedHitCount: Int
    public let candidateCount: Int
    public let totalCandidateCount: Int
    public let candidates: [SearchCandidate<ID>]

    public init(
        mode: SearchMode = .ranked,
        matchedDocumentCount: Int? = nil,
        searchedHitCount: Int? = nil,
        candidateCount: Int? = nil,
        totalCandidateCount: Int? = nil,
        candidates: [SearchCandidate<ID>]
    ) {
        let representedDocumentCount = Set(
            candidates.map(\.documentID)
        ).count

        self.mode = mode
        self.matchedDocumentCount = max(
            0,
            matchedDocumentCount ?? representedDocumentCount
        )
        self.searchedHitCount = max(
            0,
            searchedHitCount ?? representedDocumentCount
        )
        self.candidateCount = max(
            candidates.count,
            candidateCount ?? candidates.count
        )
        self.totalCandidateCount = max(
            candidates.count,
            totalCandidateCount ?? candidates.count
        )
        self.candidates = candidates
    }

    public var returnedCandidateCount: Int {
        candidates.count
    }

    public var searchWasTruncated: Bool {
        searchedHitCount < matchedDocumentCount
    }

    public var truncated: Bool {
        searchWasTruncated
            || returnedCandidateCount < totalCandidateCount
    }

    public var hasMore: Bool {
        truncated
    }

    public var isEmpty: Bool {
        candidates.isEmpty
    }

    public var count: Int {
        candidates.count
    }
}

extension SearchFrontier: Codable where ID: Codable {}
