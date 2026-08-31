import TestFlows

enum SearchFlowSuite: TestFlowRegistry {
    static let title = "Search flow tests"

    static let flows: [TestFlow] = [
        textRangeFlow,
        identifierRangeFlow,
        queryConvergenceFlow,
        fuzzyFlow,
        frontierConvergenceFlow,
        frontierSeparationFlow,
        frontierDocumentDiversityFlow,
        completenessModeFlow,
        structuralProofFlow,
    ]
}
