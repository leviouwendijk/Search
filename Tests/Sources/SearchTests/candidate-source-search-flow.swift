import Matching
import Search
import Testing

/// Diagnostics as a candidate source: each a record with fields.
private struct Diagnostics: CandidateSource {
    struct Entry: MatchCandidate {
        let matchID: String
        let message: String
        let severity: String
        let file: String

        var primaryField: MatchField {
            MatchField(name: "message", text: message, role: .primary)
        }

        var secondaryFields: [MatchField] {
            [
                MatchField(name: "severity", text: severity, role: .keyword),
                MatchField(name: "file", text: file, role: .secondary),
            ]
        }

        var metadata: MatchCandidateMetadata {
            .init()
        }
    }

    let entries: [Entry]

    func candidates() -> [Entry] {
        entries
    }
}

extension SearchTestSuite {
    static var candidateSourceSuite: TestSuite {
        TestSuite(
            "candidate-source-search",
            tags: [
                "search",
                "text",
                "fields",
            ]
        ) {
            Test(
                "a candidate source is searched across its fields, and a probe can be scoped to one"
            ) {
                let source = Diagnostics(entries: [
                    .init(matchID: "a/1", message: "cannot find 'Widget' in scope", severity: "error", file: "a.swift"),
                    .init(matchID: "b/7", message: "unused variable 'error'", severity: "warning", file: "b.swift"),
                    .init(matchID: "c/3", message: "cannot find 'Gadget' in scope", severity: "error", file: "error-handling.swift"),
                ])
                let exhaustive = SearchOptions(mode: .exhaustive, strategy: .contains, maximumResults: nil)

                let anywhere = TextSearch.search(
                    probes: [SearchProbe("error", role: .required, strategy: .contains)],
                    in: source,
                    options: exhaustive
                )
                try Expect.equal(
                    anywhere.hits.map(\.documentID),
                    ["a/1", "b/7", "c/3"],
                    "unscoped, a term matches any field: severity, message or file"
                )

                let severity = TextSearch.search(
                    probes: [SearchProbe("error", role: .required, strategy: .contains, field: "severity")],
                    in: source,
                    options: exhaustive
                )
                try Expect.equal(
                    severity.hits.map(\.documentID),
                    ["a/1", "c/3"],
                    "scoped to severity, the warning whose message mentions 'error' is left out"
                )
                try Expect.equal(
                    severity.hits.first?.evidence.first?.spans.first?.field,
                    "severity",
                    "a span names the field it matched in"
                )

                let combined = TextSearch.search(
                    probes: [
                        SearchProbe("cannot find", role: .required, strategy: .contains, field: "message"),
                        SearchProbe("error", role: .excluded, strategy: .contains, field: "file"),
                    ],
                    in: source,
                    options: exhaustive
                )
                try Expect.equal(
                    combined.hits.map(\.documentID),
                    ["a/1"],
                    "scoped required and excluded probes combine"
                )

                let missing = TextSearch.search(
                    probes: [SearchProbe("error", role: .required, strategy: .contains, field: "code")],
                    in: source,
                    options: exhaustive
                )
                try Expect.equal(missing.hits.count, 0, "a field a candidate lacks matches nothing")
            }
        }
    }
}
