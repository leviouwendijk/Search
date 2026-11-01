import Foundation
import Schema

private enum StructuredQuerySchemas {
    static let predicateReference = JSONSchema.reference(
        "#/$defs/StructuredPredicate"
    )

    static func tagged(
        _ name: String,
        properties: [JSONSchema.Property]
    ) -> JSONSchema {
        .object(
            properties: [
                JSONSchema.property(
                    name,
                    schema: .object(
                        properties: properties,
                        additionalProperties: .disallowed
                    ),
                    required: true
                )
            ],
            additionalProperties: .disallowed
        )
    }

    static var predicateDefinition: JSONSchema {
        .oneOf([
            tagged(
                "all",
                properties: [
                    JSONSchema.array(
                        "_0",
                        required: true,
                        items: predicateReference
                    )
                ]
            ),
            tagged(
                "any",
                properties: [
                    JSONSchema.array(
                        "_0",
                        required: true,
                        items: predicateReference
                    )
                ]
            ),
            tagged(
                "not",
                properties: [
                    JSONSchema.property(
                        "_0",
                        schema: predicateReference,
                        required: true
                    )
                ]
            ),
            tagged(
                "equal",
                properties: [
                    JSONSchema.string("field", required: true),
                    JSONSchema.property(
                        "value",
                        schema: StructuredValue.jsonschema,
                        required: true
                    )
                ]
            ),
            tagged(
                "between",
                properties: [
                    JSONSchema.string("field", required: true),
                    JSONSchema.property(
                        "lower",
                        schema: StructuredValue.jsonschema,
                        required: true
                    ),
                    JSONSchema.property(
                        "upper",
                        schema: StructuredValue.jsonschema,
                        required: true
                    )
                ]
            ),
            tagged(
                "oneOf",
                properties: [
                    JSONSchema.string("field", required: true),
                    JSONSchema.array(
                        "values",
                        required: true,
                        items: StructuredValue.jsonschema
                    )
                ]
            ),
            tagged(
                "exists",
                properties: [
                    JSONSchema.string("field", required: true)
                ]
            ),
            tagged(
                "text",
                properties: [
                    JSONSchema.string("field", required: true),
                    JSONSchema.string("query", required: true),
                    JSONSchema.string(
                        "strategy",
                        required: true,
                        cases: SearchStrategy.allCases.map(\.rawValue)
                    )
                ]
            )
        ])
    }
}

extension StructuredValue: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .oneOf([
            StructuredQuerySchemas.tagged(
                "text",
                properties: [JSONSchema.string("_0", required: true)]
            ),
            StructuredQuerySchemas.tagged(
                "integer",
                properties: [JSONSchema.integer("_0", required: true)]
            ),
            StructuredQuerySchemas.tagged(
                "decimal",
                properties: [JSONSchema.number("_0", required: true)]
            ),
            StructuredQuerySchemas.tagged(
                "date",
                properties: [JSONSchema.number("_0", required: true)]
            ),
            StructuredQuerySchemas.tagged(
                "boolean",
                properties: [JSONSchema.boolean("_0", required: true)]
            )
        ])
    }
}

extension StructuredValueKind: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        JSONSchema.string(cases: [
            "text", "integer", "decimal", "date", "boolean"
        ])
    }
}

extension StructuredField: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                JSONSchema.string("name", required: true),
                JSONSchema.property("kind", schema: StructuredValueKind.jsonschema, required: true),
                JSONSchema.boolean("multiple", required: true)
            ],
            additionalProperties: .disallowed
        )
    }
}

extension StructuredSchema: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                JSONSchema.array("fields", required: true, items: StructuredField.jsonschema)
            ],
            additionalProperties: .disallowed
        )
    }
}

extension StructuredPredicate: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        StructuredQuerySchemas.predicateReference.defining(
            "StructuredPredicate",
            as: StructuredQuerySchemas.predicateDefinition
        )
    }
}

extension StructuredOrdering: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .oneOf([
            StructuredQuerySchemas.tagged(
                "field",
                properties: [
                    JSONSchema.string("_0", required: true),
                    JSONSchema.boolean("ascending", required: true)
                ]
            ),
            StructuredQuerySchemas.tagged(
                "relevance",
                properties: [
                    JSONSchema.boolean("descending", required: true)
                ]
            )
        ])
    }
}

extension StructuredQuery: JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        JSONSchema.object(
            properties: [
                JSONSchema.property(
                    "predicate",
                    schema: StructuredQuerySchemas.predicateReference,
                    required: true
                ),
                JSONSchema.array("ordering", required: true, items: StructuredOrdering.jsonschema),
                JSONSchema.integer("offset", required: true),
                JSONSchema.integer("limit", required: true)
            ],
            additionalProperties: .disallowed
        ).defining(
            "StructuredPredicate",
            as: StructuredQuerySchemas.predicateDefinition
        )
    }
}

extension StructuredRecord: JSONSchemaProviding
where ID: Codable & JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                JSONSchema.property("id", schema: ID.jsonschema, required: true),
                JSONSchema.property(
                    "fields",
                    schema: .object(
                        additionalProperties: .schema(
                            JSONSchema.array(items: StructuredValue.jsonschema)
                        )
                    ),
                    required: true
                )
            ],
            additionalProperties: .disallowed
        )
    }
}

extension StructuredHit: JSONSchemaProviding
where ID: Codable & JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                JSONSchema.property("id", schema: ID.jsonschema, required: true),
                JSONSchema.integer("score", required: true),
                JSONSchema.integer("sourceOrder", required: true)
            ],
            additionalProperties: .disallowed
        )
    }
}

extension StructuredQueryResult: JSONSchemaProviding
where ID: Codable & JSONSchemaProviding {
    public static var jsonschema: JSONSchema {
        .object(
            properties: [
                JSONSchema.integer("searchedCount", required: true),
                JSONSchema.integer("matchedCount", required: true),
                JSONSchema.array(
                    "hits",
                    required: true,
                    items: StructuredHit<ID>.jsonschema
                ),
                JSONSchema.property("nextOffset", schema: Int?.jsonschema)
            ],
            additionalProperties: .disallowed
        )
    }
}
