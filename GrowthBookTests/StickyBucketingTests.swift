import XCTest

@testable import GrowthBook

class StickyBucketingFeatureTests: XCTestCase {
    var service: StickyBucketService!
    var evalConditions: [JSON]?

    override func setUp() {
        evalConditions = TestHelper().getStickyBucketingData()
        service = StickyBucketService()
    }

    func testEvaluateFeatureWithStickyBucketingFeature() {
        guard let evalConditions = evalConditions else { return }
        var failedScenarios: [String] = []
        var passedScenarios: [String] = []
                
        for item in evalConditions {
            
            let testData = FeaturesTest(json: item[1].dictionaryValue, stickyBucketingJson: item[2].arrayValue)
            let attributes = testData.attributes
            let stickyBucketAssignmentDocs = testData.stickyBucketAssignmentDocs
            let forcedVariations = testData.forcedVariations
            let features = testData.features
        
            var expectedStickyAssignmentDocs: [String: StickyAssignmentsDocument] = [:]
            
            item[5].dictionaryValue.forEach { (key, value) in
                expectedStickyAssignmentDocs[key] = StickyAssignmentsDocument(attributeName: value.dictionaryValue["attributeName"]?.stringValue ?? "", attributeValue: value.dictionaryValue["attributeValue"]?.stringValue ?? "", assignments: value.dictionaryValue["assignments"]?.dictionaryValue ?? [:])
            }
            
            let gbContext = Context(apiHost: nil,
                                    clientKey: nil,
                                    encryptionKey: nil,
                                    isEnabled: true,
                                    attributes: attributes,
                                    forcedVariations: forcedVariations,
                                    stickyBucketAssignmentDocs: stickyBucketAssignmentDocs,
                                    stickyBucketService: service,
                                    isQaMode: false,
                                    trackingClosure: { _, _ in },
                                    features: features ?? [:],
                                    backgroundSync: false)
            
            let expectedResult = ExperimentResultTest(json: item[4].dictionaryValue)
            let evaluator = FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: item[3].stringValue)
            let result = evaluator.evaluateFeature().experimentResult
            
            let status = "\(item[0].stringValue) \nExpected Result - \(expectedResult.variationId?.description) \(expectedResult.hashValue) \(expectedResult.inExperiment?.description) \(expectedResult.value?.stringValue) \(expectedResult.hashAttribute ?? "") & \(item[4].stringValue) \(expectedResult.hashUsed?.description) \nActual result - \(result?.variationId.description ?? "") \(result?.valueHash ?? "") \(result?.inExperiment.description ?? "") \(result?.value.stringValue ?? "") \(result?.hashAttribute ?? "") \(result?.hashUsed?.description) \n\n"

            if result?.variationId == expectedResult.variationId &&
                result?.value == expectedResult.value &&
                result?.stickyBucketUsed == expectedResult.stickyBucketUsed &&
                ((gbContext.stickyBucketAssignmentDocs?.allSatisfy({ (key, value) in
                    expectedStickyAssignmentDocs[key] == value
                })) != nil) 
            {
                passedScenarios.append(status)
            } else {
                failedScenarios.append(status)
            }

        }

        print("\nTOTAL TESTS - \(evalConditions.count)")
        print("Passed TESTS - \(passedScenarios.count)")
        print("Failed TESTS - \(failedScenarios.count)")

        XCTAssertTrue(failedScenarios.count == 0)
    }
}
