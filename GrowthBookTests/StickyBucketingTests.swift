import XCTest

@testable import GrowthBook

// Captures the getAllAssignments completion without calling it, so tests can
// control exactly when the async refresh resolves.
private class ManualStickyBucketService: NSObject, StickyBucketServiceProtocol {
    private var pendingCompletion: (([String: StickyAssignmentsDocument]?, Error?) -> Void)?

    func getAssignments(attributeName: String, attributeValue: String,
                        completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void) {
        completion(nil, nil)
    }

    func saveAssignments(doc: StickyAssignmentsDocument, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func getAllAssignments(attributes: [String: String],
                           completion: @escaping ([String: StickyAssignmentsDocument]?, Error?) -> Void) {
        pendingCompletion = completion
    }

    func flush(docs: [String: StickyAssignmentsDocument] = [:]) {
        pendingCompletion?(docs, nil)
        pendingCompletion = nil
    }
}

private func makeSdk(attributes: [String: Any],
                     service: StickyBucketServiceProtocol) -> GrowthBookSDK {
    let emptyFeatures = try! JSONEncoder().encode([String: Feature]())
    return GrowthBookBuilder(
        features: emptyFeatures,
        attributes: attributes,
        trackingCallback: { _, _ in },
        backgroundSync: false
    )
    .setStickyBucketService(stickyBucketService: service)
    .initializer()
}

class StickyBucketUserSwitchTests: XCTestCase {

    func testSetAttributesClearsStickyDocsBeforeRefreshCompletes() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["id": "userA"], service: service)

        let userADocs = ["id||userA": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userA",
            assignments: ["exp-1__0": "control"]
        )]
        service.flush(docs: userADocs)
        XCTAssertEqual(sdk.getGBContext().stickyBucketAssignmentDocs?["id||userA"]?.assignments["exp-1__0"], "control",
                       "Precondition: userA docs must be loaded after init flush")

        sdk.setAttributes(attributes: ["id": "userB"])

        // Before the refresh completion fires, stale userA docs must already be gone.
        XCTAssertNil(sdk.getGBContext().stickyBucketAssignmentDocs,
                     "Stale docs from previous user must be cleared synchronously on setAttributes")

        let userBDocs = ["id||userB": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userB",
            assignments: ["exp-1__0": "variant"]
        )]
        service.flush(docs: userBDocs)
        XCTAssertEqual(sdk.getGBContext().stickyBucketAssignmentDocs?["id||userB"]?.assignments["exp-1__0"], "variant",
                       "userB docs must be loaded after refresh completes")
    }

    func testAppendAttributesClearsStickyDocsBeforeRefreshCompletes() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["deviceId": "device-1"], service: service)

        let anonymousDocs = ["deviceId||device-1": StickyAssignmentsDocument(
            attributeName: "deviceId", attributeValue: "device-1",
            assignments: ["exp-1__0": "control"]
        )]
        service.flush(docs: anonymousDocs)
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs,
                        "Precondition: anonymous docs must be loaded after init flush")

        try? sdk.appendAttributes(attributes: ["id": "user-logged-in"])

        XCTAssertNil(sdk.getGBContext().stickyBucketAssignmentDocs,
                     "Stale docs must be cleared synchronously on appendAttributes")

        service.flush(docs: [:])
        XCTAssertTrue(sdk.getGBContext().stickyBucketAssignmentDocs?.isEmpty ?? true)
    }
}

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
                                    streamingHost: nil,
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
