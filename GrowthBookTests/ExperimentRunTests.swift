import XCTest

@testable import GrowthBook

class ExperimentRunTests: XCTestCase {
    var evalConditions: [JSON]?

    override func setUp() {
        evalConditions = TestHelper().getRunExperimentData()
    }

    func testExperiments() throws {
        guard let evalConditions = evalConditions else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let testContext = ContextTest(json: item[1].dictionaryValue)
            let experiment = Experiment(json: item[2].dictionaryValue)

            let gbContext = Context(isEnabled: testContext.isEnabled,
                                    attributes: testContext.attributes,
                                    forcedVariations: testContext.forcedVariations,
                                    isQaMode: testContext.isQaMode,
                                    trackingClosure: { _, _ in }, 
                                    features: testContext.features,
                                    savedGroups: testContext.savedGroups)

            let evaluator = ExperimentEvaluator()
            let result = evaluator.evaluateExperiment(context: Utils.initializeEvalContext(context: gbContext), experiment: experiment)

            let status = item[0].stringValue + "\nExpected Result - " + item[3].stringValue + " & " + item[4].stringValue + "\nActual result - " + result.value.stringValue + " & " + String(result.inExperiment) + "\n\n"

            if item[3] == result.value && item[4].boolValue == result.inExperiment {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }
        }

        logger.info("TOTAL TESTS - \(evalConditions.count)")
        logger.info("Passed TESTS - \(passedScenarios.count)")
        logger.info("Failed TESTS - \(failedScenarios.count)")

        XCTAssertTrue(failedScenarios.count == 0)
    }
}
