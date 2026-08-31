public struct SearchFrontierOptions:
    Sendable,
    Codable,
    Hashable
{
    public var mergeDistanceLines: Int
    public var maximumCandidates: Int?
    public var maximumCandidatesPerDocument: Int?
    public var offset: Int

    public init(
        mergeDistanceLines: Int = 3,
        maximumCandidates: Int? = 16,
        maximumCandidatesPerDocument: Int? = nil,
        offset: Int = 0
    ) {
        self.mergeDistanceLines = max(
            0,
            mergeDistanceLines
        )
        self.maximumCandidates = maximumCandidates.map {
            max(
                0,
                $0
            )
        }
        self.maximumCandidatesPerDocument = maximumCandidatesPerDocument.map {
            max(
                0,
                $0
            )
        }
        self.offset = max(
            0,
            offset
        )
    }

    public static let defaults: Self = .init()
}
