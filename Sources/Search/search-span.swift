import Position

public struct SearchSpan:
    Sendable,
    Codable,
    Hashable
{
    public let range: PositionRange
    public let lineRange: LineRange

    public init(
        range: PositionRange,
        lineRange: LineRange
    ) {
        self.range = range
        self.lineRange = lineRange
    }
}
