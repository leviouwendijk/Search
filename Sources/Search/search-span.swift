import Position

public struct SearchSpan:
    Sendable,
    Codable,
    Hashable
{
    public let range: PositionRange
    public let lineRange: LineRange
    /// The candidate field the span is in; positions count within it.
    public let field: String?

    public init(
        range: PositionRange,
        lineRange: LineRange,
        field: String? = nil
    ) {
        self.range = range
        self.lineRange = lineRange
        self.field = field
    }
}
