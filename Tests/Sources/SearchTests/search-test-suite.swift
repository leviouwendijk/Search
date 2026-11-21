import Testing

enum SearchTestSuite {
    static let suite = TestSuite(
        "search",
        title: "Search tests"
    ) {
        textRangeSuite
        identifierRangeSuite
        candidateSourceSuite
        probeSemanticsSuite
        queryConvergenceSuite
        fuzzySuite
        frontierConvergenceSuite
        frontierSeparationSuite
        frontierDocumentDiversitySuite
        completenessModeSuite
        lexicalSearchSuite
        structuralProofSuite
        structuralAccelerationSuite
    }
}
