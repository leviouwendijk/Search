public struct SearchFrontier<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let mode: SearchMode
    public let matchedDocumentCount: Int
    public let searchedHitCount: Int
    public let discoveredCandidateCount: Int
    public let totalCandidateCount: Int
    public let offset: Int
    public let candidates: [SearchCandidate<ID>]

    public init(
        mode: SearchMode = .ranked,
        matchedDocumentCount: Int? = nil,
        searchedHitCount: Int? = nil,
        discoveredCandidateCount: Int? = nil,
        totalCandidateCount: Int? = nil,
        offset: Int = 0,
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
        self.discoveredCandidateCount = max(
            candidates.count,
            discoveredCandidateCount ?? candidates.count
        )
        self.totalCandidateCount = max(
            candidates.count,
            totalCandidateCount ?? candidates.count
        )
        self.offset = max(
            0,
            offset
        )
        self.candidates = candidates
    }

    public var returnedCandidateCount: Int {
        candidates.count
    }

    public var searchWasTruncated: Bool {
        searchedHitCount < matchedDocumentCount
    }

    public var hasMore: Bool {
        guard offset < totalCandidateCount else {
            return false
        }

        return returnedCandidateCount
            < totalCandidateCount - offset
    }

    public var nextOffset: Int? {
        guard hasMore,
              returnedCandidateCount > 0
        else {
            return nil
        }

        return offset + returnedCandidateCount
    }

    public var truncated: Bool {
        searchWasTruncated
            || (totalCandidateCount > 0 && offset > 0)
            || hasMore
    }

    public var isEmpty: Bool {
        candidates.isEmpty
    }

    public var count: Int {
        candidates.count
    }
}

extension SearchFrontier: Codable where ID: Codable {}
