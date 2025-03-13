import XCTest

@testable import GrowthBook

class FeatureValueTests: XCTestCase {

    var evalConditions: [JSON]?

    override func setUp() {
        evalConditions = TestHelper().getFeatureData()
    }

    func testFeatures() throws {
        guard let evalConditions = evalConditions else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
        for item in evalConditions {
            let testData = FeaturesTest(json: item[1].dictionaryValue)

            let gbContext = Context(isEnabled: true,
                                    attributes: testData.attributes,
                                    forcedVariations: testData.forcedVariations,
                                    isQaMode: false,
                                    trackingClosure: { _, _ in }, 
                                    savedGroups: testData.savedGroups)

            if let features = testData.features {
                gbContext.features = features
            }
            
            let evaluator = FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: item[2].stringValue)
            let result = evaluator.evaluateFeature()

            let expectedResult = FeatureResultTest(json: item[3].dictionaryValue)

            let status = "\(item[0].stringValue) \nExpected Result - \nValue - \(expectedResult.value) \nOn - \(expectedResult.isOn) \nOff - \(expectedResult.isOff) \nSource - \(expectedResult.source) \nExperiment - \(expectedResult.experiment?.key ?? "") \nExperiment Result - \(expectedResult.experimentResult?.variationId ?? 0) \nActual result - \nValue - \(result.value?.stringValue ?? "") \nOn - \(result.isOn) \nOff - \(result.isOff) \nSource - \(result.source) \nExperiment - \(result.experiment?.key ?? "") \nExperiment Result - \(result.experimentResult?.variationId ?? 0) \n\n"

            if result.value == expectedResult.value &&
                result.isOn == expectedResult.isOn &&
                result.isOff == expectedResult.isOff &&
                result.source == expectedResult.source &&
                result.experiment?.key == expectedResult.experiment?.key &&
                result.experimentResult?.variationId == expectedResult.experimentResult?.variationId {
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
