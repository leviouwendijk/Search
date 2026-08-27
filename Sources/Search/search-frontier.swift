public struct SearchFrontier<ID: Hashable & Sendable>:
    Sendable,
    Hashable
{
    public let candidates: [SearchCandidate<ID>]

    public init(
        candidates: [SearchCandidate<ID>]
    ) {
        self.candidates = candidates
    }

    public var isEmpty: Bool {
        candidates.isEmpty
    }

    public var count: Int {
        candidates.count
    }
}

extension SearchFrontier: Codable where ID: Codable {}
