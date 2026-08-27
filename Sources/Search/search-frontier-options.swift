public struct SearchFrontierOptions:
    Sendable,
    Codable,
    Hashable
{
    public var mergeDistanceLines: Int
    public var maximumCandidates: Int?

    public init(
        mergeDistanceLines: Int = 3,
        maximumCandidates: Int? = 16
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
    }

    public static let defaults: Self = .init()
}
