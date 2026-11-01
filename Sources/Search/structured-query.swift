import Foundation
import Schema

public enum StructuredValue: Sendable, Codable, Hashable {
    case text(String)
    case integer(Int64)
    case decimal(Decimal)
    case date(Date)
    case boolean(Bool)

    public var kind: StructuredValueKind {
        switch self {
        case .text: .text
        case .integer: .integer
        case .decimal: .decimal
        case .date: .date
        case .boolean: .boolean
        }
    }
}

public enum StructuredValueKind: String, Sendable, Codable, Hashable {
    case text, integer, decimal, date, boolean
}

public struct StructuredField: Sendable, Codable, Hashable {
    public let name: String
    public let kind: StructuredValueKind
    public let multiple: Bool

    public init(_ name: String, kind: StructuredValueKind, multiple: Bool = false) {
        self.name = name
        self.kind = kind
        self.multiple = multiple
    }
}

public struct StructuredSchema: Sendable, Codable, Hashable {
    public let fields: [StructuredField]

    public init(fields: [StructuredField]) {
        self.fields = fields
    }
}

public indirect enum StructuredPredicate: Sendable, Codable, Hashable {
    case all([StructuredPredicate])
    case any([StructuredPredicate])
    case not(StructuredPredicate)
    case equal(field: String, value: StructuredValue)
    case between(field: String, lower: StructuredValue, upper: StructuredValue)
    case oneOf(field: String, values: [StructuredValue])
    case exists(field: String)
    case text(field: String, query: String, strategy: SearchStrategy)
}

public enum StructuredOrdering: Sendable, Codable, Hashable {
    case field(String, ascending: Bool)
    case relevance(descending: Bool)
}

public struct StructuredQuery: Sendable, Codable, Hashable {
    public let predicate: StructuredPredicate
    public let ordering: [StructuredOrdering]
    public let offset: Int
    public let limit: Int

    public init(
        predicate: StructuredPredicate = .all([]),
        ordering: [StructuredOrdering] = [],
        offset: Int = 0,
        limit: Int = 50
    ) {
        self.predicate = predicate
        self.ordering = ordering
        self.offset = offset
        self.limit = limit
    }
}

public struct StructuredRecord<ID: Hashable & Sendable>: Sendable {
    public let id: ID
    public let fields: [String: [StructuredValue]]

    public init(id: ID, fields: [String: [StructuredValue]]) {
        self.id = id
        self.fields = fields
    }
}

extension StructuredRecord: Codable where ID: Codable {}
extension StructuredRecord: Hashable where ID: Hashable {}

public struct StructuredHit<ID: Hashable & Sendable>: Sendable, Hashable {
    public let id: ID
    public let score: Int
    public let sourceOrder: Int
}

extension StructuredHit: Codable where ID: Codable {}

public struct StructuredQueryResult<ID: Hashable & Sendable>: Sendable {
    public let searchedCount: Int
    public let matchedCount: Int
    public let hits: [StructuredHit<ID>]
    public let nextOffset: Int?

    public var truncated: Bool { nextOffset != nil }
}

extension StructuredQueryResult: Codable where ID: Codable {}

public enum StructuredQueryFailure: Error, Equatable, Sendable {
    case invalidSchema(String)
    case unknownField(String)
    case typeMismatch(field: String, expected: StructuredValueKind)
    case invalidPredicate(String)
    case invalidPagination
    case invalidRecord(field: String)
}

public enum StructuredQueryEngine {
    public static func execute<ID: Hashable & Sendable>(
        _ query: StructuredQuery,
        in records: [StructuredRecord<ID>],
        schema: StructuredSchema
    ) throws -> StructuredQueryResult<ID> {
        guard query.offset >= 0, (1...500).contains(query.limit) else {
            throw StructuredQueryFailure.invalidPagination
        }

        var definitions: [String: StructuredField] = [:]
        for field in schema.fields {
            guard !field.name.isEmpty,
                  definitions.updateValue(field, forKey: field.name) == nil else {
                throw StructuredQueryFailure.invalidSchema(field.name)
            }
        }

        try validate(query.predicate, definitions: definitions)
        for order in query.ordering {
            if case .field(let name, _) = order, definitions[name] == nil {
                throw StructuredQueryFailure.unknownField(name)
            }
        }

        var matches: [(hit: StructuredHit<ID>, record: StructuredRecord<ID>)] = []

        for (index, record) in records.enumerated() {
            for (name, values) in record.fields {
                guard let definition = definitions[name] else {
                    throw StructuredQueryFailure.unknownField(name)
                }
                guard (definition.multiple || values.count <= 1),
                      values.allSatisfy({ $0.kind == definition.kind }) else {
                    throw StructuredQueryFailure.invalidRecord(field: name)
                }
            }

            if let score = evaluate(query.predicate, in: record) {
                matches.append((
                    hit: StructuredHit(id: record.id, score: score, sourceOrder: index),
                    record: record
                ))
            }
        }

        matches.sort { lhs, rhs in
            for order in query.ordering {
                let comparison: ComparisonResult
                let ascending: Bool

                switch order {
                case .field(let name, let value):
                    comparison = compareOptional(
                        lhs.record.fields[name]?.first,
                        rhs.record.fields[name]?.first
                    )
                    ascending = value
                case .relevance(let descending):
                    comparison = compareIntegers(lhs.hit.score, rhs.hit.score)
                    ascending = !descending
                }

                if comparison == .orderedSame { continue }
                return ascending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            }
            return lhs.hit.sourceOrder < rhs.hit.sourceOrder
        }

        let matchedCount = matches.count
        let hits = Array(matches.dropFirst(query.offset).prefix(query.limit)).map(\.hit)
        let consumed = query.offset + hits.count

        return StructuredQueryResult(
            searchedCount: records.count,
            matchedCount: matchedCount,
            hits: hits,
            nextOffset: consumed < matchedCount ? consumed : nil
        )
    }

    private static func field(
        _ name: String,
        in definitions: [String: StructuredField]
    ) throws -> StructuredField {
        guard let definition = definitions[name] else {
            throw StructuredQueryFailure.unknownField(name)
        }
        return definition
    }

    private static func validate(
        _ predicate: StructuredPredicate,
        definitions: [String: StructuredField]
    ) throws {
        switch predicate {
        case .all(let children), .any(let children):
            for child in children {
                try validate(child, definitions: definitions)
            }
        case .not(let child):
            try validate(child, definitions: definitions)
        case .exists(let name):
            _ = try field(name, in: definitions)
        case .equal(let name, let value):
            let definition = try field(name, in: definitions)
            guard value.kind == definition.kind else {
                throw StructuredQueryFailure.typeMismatch(
                    field: name, expected: definition.kind
                )
            }
        case .oneOf(let name, let values):
            let definition = try field(name, in: definitions)
            guard !values.isEmpty else {
                throw StructuredQueryFailure.invalidPredicate("empty oneOf")
            }
            guard values.allSatisfy({ $0.kind == definition.kind }) else {
                throw StructuredQueryFailure.typeMismatch(
                    field: name, expected: definition.kind
                )
            }
        case .between(let name, let lower, let upper):
            let definition = try field(name, in: definitions)
            guard lower.kind == definition.kind,
                  upper.kind == definition.kind else {
                throw StructuredQueryFailure.typeMismatch(
                    field: name, expected: definition.kind
                )
            }
            guard definition.kind != .boolean,
                  let order = compare(lower, upper),
                  order != .orderedDescending else {
                throw StructuredQueryFailure.invalidPredicate("invalid range")
            }
        case .text(let name, let query, _):
            let definition = try field(name, in: definitions)
            guard definition.kind == .text else {
                throw StructuredQueryFailure.typeMismatch(
                    field: name, expected: .text
                )
            }
            guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw StructuredQueryFailure.invalidPredicate("empty text query")
            }
        }
    }

    private static func evaluate<ID: Hashable & Sendable>(
        _ predicate: StructuredPredicate,
        in record: StructuredRecord<ID>
    ) -> Int? {
        switch predicate {
        case .all(let children):
            var score = 0
            for child in children {
                guard let contribution = evaluate(child, in: record) else {
                    return nil
                }
                score += contribution
            }
            return score
        case .any(let children):
            return children.compactMap { evaluate($0, in: record) }.max()
        case .not(let child):
            return evaluate(child, in: record) == nil ? 0 : nil
        case .exists(let name):
            return record.fields[name]?.isEmpty == false ? 0 : nil
        case .equal(let name, let value):
            return record.fields[name]?.contains(value) == true ? 0 : nil
        case .oneOf(let name, let values):
            return record.fields[name]?.contains(where: { values.contains($0) }) == true
                ? 0 : nil
        case .between(let name, let lower, let upper):
            let accepted = record.fields[name]?.contains { candidate in
                guard let first = compare(candidate, lower),
                      let last = compare(candidate, upper) else {
                    return false
                }
                return first != .orderedAscending && last != .orderedDescending
            } ?? false
            return accepted ? 0 : nil
        case .text(let name, let query, let strategy):
            var best: Int?
            for value in record.fields[name] ?? [] {
                guard case .text(let candidate) = value else { continue }
                let corpus = SearchCorpus(documents: [
                    SearchDocument(id: 0, text: candidate)
                ])
                let result = TextSearch.search(
                    probes: [SearchProbe(query, role: .required, strategy: strategy)],
                    in: corpus,
                    options: .init(
                        mode: .exhaustive,
                        strategy: strategy,
                        minimumScore: nil,
                        maximumResults: nil
                    )
                )
                if let score = result.hits.first?.score.value {
                    best = max(best ?? score, score)
                }
            }
            return best
        }
    }

    private static func compareIntegers(_ lhs: Int, _ rhs: Int) -> ComparisonResult {
        lhs == rhs ? .orderedSame : (
            lhs < rhs ? .orderedAscending : .orderedDescending
        )
    }

    private static func compareOptional(
        _ lhs: StructuredValue?,
        _ rhs: StructuredValue?
    ) -> ComparisonResult {
        switch (lhs, rhs) {
        case (nil, nil): .orderedSame
        case (nil, _): .orderedDescending
        case (_, nil): .orderedAscending
        case (.some(let left), .some(let right)):
            compare(left, right) ?? .orderedSame
        }
    }

    private static func compare(
        _ lhs: StructuredValue,
        _ rhs: StructuredValue
    ) -> ComparisonResult? {
        switch (lhs, rhs) {
        case (.text(let a), .text(let b)):
            a.compare(b, options: .literal)
        case (.integer(let a), .integer(let b)):
            a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        case (.decimal(let a), .decimal(let b)):
            a == b ? .orderedSame : (a < b ? .orderedAscending : .orderedDescending)
        case (.date(let a), .date(let b)):
            a.compare(b)
        case (.boolean(let a), .boolean(let b)):
            a == b ? .orderedSame : (!a ? .orderedAscending : .orderedDescending)
        default:
            nil
        }
    }
}
