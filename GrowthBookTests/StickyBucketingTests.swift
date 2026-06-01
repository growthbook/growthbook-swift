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

class AttributeOverridesTests: XCTestCase {

    // Verifies that refreshStickyBucketService uses merged (base + override) attributes
    // for the getAllAssignments call, so docs keyed on override attributes are fetched.
    func testAttributeOverridesAreUsedInStickyBucketLookup() {
        let service = ManualStickyBucketService()
        // Base attributes have no "id"; override supplies it.
        let sdk = makeSdk(attributes: ["deviceId": "device-1"], service: service)
        service.flush(docs: [:])

        sdk.setAttributeOverrides(overrides: ["id": "user-from-override"])
        let overrideDocs = ["id||user-from-override": StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-from-override",
            assignments: ["exp-1__0": "variant"]
        )]
        service.flush(docs: overrideDocs)

        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||user-from-override"],
                        "Sticky doc keyed on override attribute must be fetched and loaded")
    }

    // Verifies that setAttributes clears attributeOverrides so the previous user's
    // overrides don't bleed into the new user's sticky bucket lookup.
    func testSetAttributesResetsAttributeOverrides() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["deviceId": "device-1"], service: service)
        service.flush(docs: [:])

        sdk.setAttributeOverrides(overrides: ["id": "override-id"])
        let overrideDocs = ["id||override-id": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "override-id",
            assignments: ["exp-1__0": "control"]
        )]
        service.flush(docs: overrideDocs)
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||override-id"],
                        "Precondition: override docs must be loaded")

        // Switch user — must clear overrides so new user doesn't inherit them.
        sdk.setAttributes(attributes: ["id": "new-user"])
        let newUserDocs = ["id||new-user": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "new-user",
            assignments: ["exp-1__0": "variant"]
        )]
        service.flush(docs: newUserDocs)

        XCTAssertNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||override-id"],
                     "Override docs from previous context must be gone after setAttributes")
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||new-user"],
                        "New user docs must be loaded after setAttributes")
    }

    // Verifies that attributeOverrides are merged into userContext.attributes and
    // therefore affect experiment evaluation (via hashAttribute lookup).
    func testAttributeOverridesAreAppliedToEvaluation() {
        let service = ManualStickyBucketService()
        // Base attributes have no "id" — experiments hashing on "id" won't bucket the user.
        let sdk = makeSdk(attributes: ["deviceId": "device-only"], service: service)
        service.flush(docs: [:])

        let experiment = Experiment(
            key: "test-exp",
            variations: [JSON("control"), JSON("variant")],
            hashAttribute: "id",
            coverage: 1.0
        )

        let before = sdk.run(experiment: experiment)
        XCTAssertFalse(before.inExperiment, "Without id attribute, user must not be bucketed")

        sdk.setAttributeOverrides(overrides: ["id": "user-with-override"])
        // No flush needed: updateEvalData already invalidated the context cache,
        // so the next run() call gets a fresh EvalContext with merged attributes.

        let after = sdk.run(experiment: experiment)
        XCTAssertTrue(after.inExperiment,
                      "id from attributeOverrides must be applied to experiment evaluation")
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
