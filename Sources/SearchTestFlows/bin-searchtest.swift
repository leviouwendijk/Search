import TestFlows

@main
enum SearchFlowMain {
    static func main() async {
        await TestFlowCLI.run(
            suite: SearchFlowSuite.self
        )
    }
}
