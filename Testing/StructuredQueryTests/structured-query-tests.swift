import Foundation
import Search

@main
struct StructuredQueryTests {
    static func main() throws {
        let schema = StructuredSchema(fields: [
            .init("id", kind: .integer),
            .init("amount", kind: .decimal),
            .init("details", kind: .text),
            .init("accounts", kind: .text, multiple: true)
        ])

        let records: [StructuredRecord<Int>] = [
            .init(id: 1, fields: [
                "id": [.integer(1200)],
                "amount": [.decimal(Decimal(string: "0.01")!)],
                "details": [.text("Invoice INV-1042 PayNL")],
                "accounts": [.text("WBed"), .text("BLim")]
            ]),
            .init(id: 2, fields: [
                "id": [.integer(1300)],
                "amount": [.decimal(Decimal(string: "0.02")!)],
                "details": [.text("Invoice INV-1042 settled")],
                "accounts": [.text("BLim")]
            ]),
            .init(id: 3, fields: [
                "id": [.integer(1500)],
                "amount": [.decimal(Decimal(string: "1.00")!)],
                "details": [.text("Unrelated")],
                "accounts": [.text("WBed")]
            ])
        ]

        let predicate = StructuredPredicate.all([
            .between(field: "id", lower: .integer(1000), upper: .integer(1400)),
            .equal(field: "accounts", value: .text("WBed")),
            .text(field: "details", query: "INV-1042", strategy: .contains)
        ])

        let filtered = try StructuredQueryEngine.execute(
            .init(predicate: predicate), in: records, schema: schema
        )
        try check(filtered.hits.map(\.id) == [1], "composed filters")
        try check(filtered.matchedCount == 1, "matched cardinality")
        try check(filtered.searchedCount == 3, "searched cardinality")

        let first = try StructuredQueryEngine.execute(
            .init(
                predicate: .oneOf(
                    field: "id", values: [.integer(1200), .integer(1300)]
                ),
                ordering: [.field("id", ascending: false)],
                limit: 1
            ),
            in: records, schema: schema
        )
        try check(first.hits.map(\.id) == [2], "descending order")
        try check(first.nextOffset == 1, "pagination continuation")

        let second = try StructuredQueryEngine.execute(
            .init(
                predicate: .oneOf(
                    field: "id", values: [.integer(1200), .integer(1300)]
                ),
                ordering: [.field("id", ascending: false)],
                offset: 1,
                limit: 1
            ),
            in: records, schema: schema
        )
        try check(second.hits.map(\.id) == [1], "second page")
        try check(!second.truncated, "final page")

        let precise = try StructuredQueryEngine.execute(
            .init(predicate: .between(
                field: "amount",
                lower: .decimal(Decimal(string: "0.01")!),
                upper: .decimal(Decimal(string: "0.01")!)
            )),
            in: records, schema: schema
        )
        try check(precise.hits.map(\.id) == [1], "decimal exactness")

        let emptyAny = try StructuredQueryEngine.execute(
            .init(predicate: .any([])), in: records, schema: schema
        )
        try check(emptyAny.matchedCount == 0, "empty disjunction")

        let full = try StructuredQueryEngine.execute(
            .init(), in: records, schema: schema
        )
        try check(full.matchedCount == 3, "empty conjunction")

        let encoded = try JSONEncoder().encode(StructuredQuery(predicate: predicate))
        let decoded = try JSONDecoder().decode(StructuredQuery.self, from: encoded)
        try check(decoded.predicate == predicate, "serialization roundtrip")

        try reject("unknown field") {
            _ = try StructuredQueryEngine.execute(
                .init(predicate: .exists(field: "missing")),
                in: records, schema: schema
            )
        }
        try reject("type mismatch") {
            _ = try StructuredQueryEngine.execute(
                .init(predicate: .equal(field: "id", value: .text("1200"))),
                in: records, schema: schema
            )
        }
        try reject("invalid range") {
            _ = try StructuredQueryEngine.execute(
                .init(predicate: .between(
                    field: "id", lower: .integer(5), upper: .integer(1)
                )),
                in: records, schema: schema
            )
        }
        try reject("invalid pagination") {
            _ = try StructuredQueryEngine.execute(
                .init(limit: 0), in: records, schema: schema
            )
        }

        try StructuredQuerySchemaRegression.run()

        print("structuredquerytest: passed")
    }

    private static func check(_ condition: Bool, _ message: String) throws {
        guard condition else { throw Failure.assertion(message) }
    }

    private static func reject(
        _ name: String,
        operation: () throws -> Void
    ) throws {
        do {
            try operation()
        } catch {
            return
        }
        throw Failure.assertion("Expected rejection: \(name)")
    }

    private enum Failure: Error {
        case assertion(String)
    }
}
