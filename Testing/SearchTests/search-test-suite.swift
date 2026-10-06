import Testing

enum SearchTestSuite {
    static let suite = TestSuite(
        "search",
        title: "Search tests"
    ) {
        textRangeSuite
        identifierRangeSuite
        probeSemanticsSuite
        queryConvergenceSuite
        fuzzySuite
        frontierConvergenceSuite
        frontierSeparationSuite
        frontierDocumentDiversitySuite
        completenessModeSuite
        lexicalSearchSuite
        structuralProofSuite
    }
}
