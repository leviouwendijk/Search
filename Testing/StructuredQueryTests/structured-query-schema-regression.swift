import Foundation
import Primitives
import Schema
import Search

enum StructuredQuerySchemaRegression {
    static func run() throws {
        let predicate = StructuredPredicate.all([
            .between(
                field: "id",
                lower: .integer(10),
                upper: .integer(20)
            ),
            .not(.exists(field: "excluded")),
            .text(
                field: "details",
                query: "INV-1042",
                strategy: .contains
            )
        ])
        let query = StructuredQuery(
            predicate: predicate,
            ordering: [
                .field("id", ascending: true),
                .relevance(descending: true)
            ],
            offset: 0,
            limit: 50
        )
        try validate(query, against: StructuredQuery.jsonschema)
        try validate(predicate, against: StructuredPredicate.jsonschema)
        try validate(
            StructuredValue.decimal(Decimal(string: "12.34")!),
            against: StructuredValue.jsonschema
        )
        try validate(
            StructuredValue.date(Date(timeIntervalSince1970: 0)),
            against: StructuredValue.jsonschema
        )
        try validate(
            StructuredOrdering.field("id", ascending: false),
            against: StructuredOrdering.jsonschema
        )
        try validate(
            StructuredField("id", kind: .integer),
            against: StructuredField.jsonschema
        )
        try validate(
            StructuredSchema(fields: [
                .init("id", kind: .integer)
            ]),
            against: StructuredSchema.jsonschema
        )
        try validate(
            StructuredRecord(id: 7, fields: [
                "id": [.integer(7)]
            ]),
            against: StructuredRecord<Int>.jsonschema
        )

        let queryValue = try JSONCoding.default.value(query)
        guard case .object(var bad) = queryValue else {
            throw Failure.invalidShape
        }
        bad["offset"] = .string("not-an-integer")
        let malformed = JSONValue.object(bad)
        guard !StructuredQuery.jsonschema.diagnostics(malformed).isEmpty else {
            throw Failure.acceptedInvalidValue
        }
        print("structuredqueryschematest: passed")
    }

    static func validate<T: Encodable>(
        _ value: T,
        against schema: JSONSchema
    ) throws {
        let encoded = try JSONCoding.default.value(value)
        let diagnostics = schema.diagnostics(encoded)
        guard diagnostics.isEmpty else {
            throw Failure.schemaMismatch(String(describing: diagnostics))
        }
    }

    enum Failure: Error {
        case invalidShape
        case acceptedInvalidValue
        case schemaMismatch(String)
    }
}
