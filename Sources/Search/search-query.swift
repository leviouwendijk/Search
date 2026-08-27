import Foundation

public struct SearchQuery:
    Sendable,
    Codable,
    Hashable
{
    public let id: String?
    public let text: String
    public let weight: Int

    public init(
        _ text: String,
        id: String? = nil,
        weight: Int = 1
    ) {
        self.id = id
        self.text = text
        self.weight = max(
            1,
            weight
        )
    }

    public var isEmpty: Bool {
        text.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        .isEmpty
    }
}
