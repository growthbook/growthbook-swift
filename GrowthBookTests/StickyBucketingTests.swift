import XCTest

@testable import GrowthBook

// Captures getAllAssignments completions without calling them, so tests control exactly when — and
// in which order — each async refresh resolves. Completions are queued rather than replaced, which
// is what lets a test resolve a newer request before an older one that is still in flight.
private class ManualStickyBucketService: NSObject, StickyBucketServiceProtocol {
    private var pendingCompletions: [([String: StickyAssignmentsDocument]?, Error?) -> Void] = []

    var pendingCount: Int { pendingCompletions.count }

    func getAssignments(attributeName: String, attributeValue: String,
                        completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void) {
        completion(nil, nil)
    }

    func saveAssignments(doc: StickyAssignmentsDocument, completion: @escaping (Error?) -> Void) {
        completion(nil)
    }

    func getAllAssignments(attributes: [String: String],
                           completion: @escaping ([String: StickyAssignmentsDocument]?, Error?) -> Void) {
        pendingCompletions.append(completion)
    }

    /// Resolves the oldest pending request — the single-request behaviour most tests rely on.
    func flush(docs: [String: StickyAssignmentsDocument] = [:]) {
        guard !pendingCompletions.isEmpty else { return }
        let completion = pendingCompletions.removeFirst()
        completion(docs, nil)
    }

    /// Resolves one specific pending request, so a test can complete them out of order.
    func complete(_ index: Int, with docs: [String: StickyAssignmentsDocument]) {
        guard pendingCompletions.indices.contains(index) else { return }
        let completion = pendingCompletions.remove(at: index)
        completion(docs, nil)
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

    /// A custom service is free to resolve out of order, so the request started for userA can
    /// complete after the one started for userB. The late userA documents belong to a user the SDK
    /// has already left and must not win by completion order.
    func testStaleRefreshCompletionDoesNotOverwriteNewerUser() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["id": "userA"], service: service)

        XCTAssertEqual(service.pendingCount, 1, "Precondition: init started a refresh for userA")

        sdk.setAttributes(attributes: ["id": "userB"])
        XCTAssertEqual(service.pendingCount, 2, "setAttributes must start a second refresh")

        let userADocs = ["id||userA": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userA",
            assignments: ["exp-1__0": "control"]
        )]
        let userBDocs = ["id||userB": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userB",
            assignments: ["exp-1__0": "variant"]
        )]

        service.complete(1, with: userBDocs)   // newer request wins the race
        service.complete(0, with: userADocs)   // superseded request lands afterwards

        let docs = sdk.getGBContext().stickyBucketAssignmentDocs
        XCTAssertEqual(docs?["id||userB"]?.assignments["exp-1__0"], "variant",
                       "Documents of the current user must survive a late completion for the previous one")
        XCTAssertNil(docs?["id||userA"],
                     "Documents from the superseded request must be discarded, not merged in")
    }

    /// Control for the test above: in the natural order the newest completion is the one applied.
    func testLatestRefreshCompletionIsAppliedWhenItResolvesLast() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["id": "userA"], service: service)

        sdk.setAttributes(attributes: ["id": "userB"])
        XCTAssertEqual(service.pendingCount, 2)

        let userADocs = ["id||userA": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userA",
            assignments: ["exp-1__0": "control"]
        )]
        let userBDocs = ["id||userB": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "userB",
            assignments: ["exp-1__0": "variant"]
        )]

        service.complete(0, with: userADocs)   // stale request resolves first
        service.complete(0, with: userBDocs)   // then the current one

        let docs = sdk.getGBContext().stickyBucketAssignmentDocs
        XCTAssertEqual(docs?["id||userB"]?.assignments["exp-1__0"], "variant")
        XCTAssertNil(docs?["id||userA"], "The stale documents must not linger once the current request lands")
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

class FeatureLoadRaceConditionTests: XCTestCase {

    // Verifies that features are applied to the context only after sticky bucket
    // docs are loaded, so an evaluation immediately after featuresFetchedSuccessfully
    // never sees features without docs (Kotlin onPayloadReady pattern).
    func testFeaturesAppliedAfterStickyDocsLoaded() {
        let service = ManualStickyBucketService()
        let sdk = makeSdk(attributes: ["id": "user-1"], service: service)

        // Complete the init refresh.
        service.flush(docs: [:])

        // Simulate featuresFetchedSuccessfully by calling it directly.
        let newFeatures: [String: Feature] = ["my-feature": Feature(defaultValue: JSON(true), rules: nil)]
        sdk.featuresFetchedSuccessfully(features: newFeatures, isRemote: true)

        // Before the sticky bucket refresh completion fires, features must NOT be applied yet.
        XCTAssertNil(sdk.getFeatures()["my-feature"],
                     "Features must not be visible before sticky bucket docs are loaded")

        // Flush docs — features must appear together with docs.
        let docs = ["id||user-1": StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-1",
            assignments: ["exp-1__0": "variant"]
        )]
        service.flush(docs: docs)

        XCTAssertNotNil(sdk.getFeatures()["my-feature"],
                        "Features must be visible after sticky bucket docs are loaded")
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||user-1"],
                        "Sticky docs must be loaded together with features")
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

// MARK: - Remote eval payload

/// Records the POST body of every remote-eval request so tests can assert on what the server
/// would actually be asked to evaluate.
private class CapturingNetworkClient: NetworkProtocol {
    private(set) var capturedParams: [[String: Any]] = []

    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        successResult(Data("{\"features\":{}}".utf8))
    }

    func consumePOSTRequest(url: String, params: [String: Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        capturedParams.append(params)
        successResult(Data("{\"features\":{}}".utf8))
    }

    var lastAttributes: [String: Any]? { capturedParams.last?["attributes"] as? [String: Any] }
}

class RemoteEvalPayloadTests: XCTestCase {

    private func makeRemoteEvalSdk(network: NetworkProtocol) -> GrowthBookSDK {
        GrowthBookBuilder(apiHost: "https://host.com",
                          clientKey: "key",
                          attributes: ["id": "user-1", "country": "PL"],
                          trackingCallback: { _, _ in },
                          refreshHandler: nil,
                          backgroundSync: false,
                          remoteEval: true,
                          // ttlSeconds: 0 keeps this test about payload content: the TTL gate on
                          // remote-eval refreshes is a separate concern, fixed on its own branch.
                          ttlSeconds: 0)
            .setNetworkDispatcher(networkDispatcher: network)
            .initializer()
    }

    /// Local evaluation runs on attributes with the overrides merged in, so the remote payload has
    /// to carry the same effective attributes — otherwise the server evaluates a user the SDK has
    /// already stopped seeing.
    func testOverridesAreIncludedInRemoteEvalPayload() {
        let network = CapturingNetworkClient()
        let sdk = makeRemoteEvalSdk(network: network)

        sdk.setAttributeOverrides(overrides: ["country": "UA"])

        let attributes = network.lastAttributes
        XCTAssertEqual(attributes?["country"] as? String, "UA",
                       "The overridden attribute must be sent to the remote-eval endpoint")
        XCTAssertEqual(attributes?["id"] as? String, "user-1",
                       "Base attributes that are not overridden must still be sent")
    }

    /// Clearing the overrides has to be visible to the server too.
    func testClearedOverridesRevertRemoteEvalPayloadToBaseAttributes() {
        let network = CapturingNetworkClient()
        let sdk = makeRemoteEvalSdk(network: network)

        sdk.setAttributeOverrides(overrides: ["country": "UA"])
        sdk.setAttributeOverrides(overrides: [String: Any]())

        XCTAssertEqual(network.lastAttributes?["country"] as? String, "PL",
                       "With the overrides lifted the payload must fall back to the base attributes")
    }
}
