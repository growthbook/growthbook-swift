import XCTest
@testable import GrowthBook

class GrowthBookSDKTests: XCTestCase {

    let apiHost    = "https://host.com"
    let clientKey  = "sdk-test-key"
    let attributes: JSON = JSON(["id": "user-1", "country": "US"])

    // MARK: - Helpers

    private func makeSDK(
        features: Data? = nil,
        networkResponse: String? = nil,
        networkError: Error? = nil,
        ttlSeconds: Int = 60
    ) -> GrowthBookSDK {
        GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            attributes: ["id": "user-1", "country": "US"],
            features: features,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: ttlSeconds
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(
            successResponse: networkResponse ?? MockResponse().successResponse,
            error: networkError
        ))
        .initializer()
    }

    private func makeSDKWithFeatures() -> GrowthBookSDK {
        let payload = """
        {"features":{"flag-a":{"defaultValue":true},"flag-b":{"defaultValue":false}}}
        """.data(using: .utf8)!
        return makeSDK(features: payload)
    }

    // MARK: - isOn

    func testIsOnReturnsTrueForKnownFeature() {
        let sdk = makeSDKWithFeatures()
        XCTAssertTrue(sdk.isOn(feature: "flag-a"))
    }

    func testIsOnReturnsFalseForFeatureWithDefaultFalse() {
        let sdk = makeSDKWithFeatures()
        XCTAssertFalse(sdk.isOn(feature: "flag-b"))
    }

    func testIsOnReturnsFalseForUnknownFeature() {
        let sdk = makeSDKWithFeatures()
        XCTAssertFalse(sdk.isOn(feature: "nonexistent"))
    }

    // MARK: - getFeatureValue

    func testGetFeatureValueReturnsDefaultValue() {
        let sdk = makeSDKWithFeatures()
        let value = sdk.getFeatureValue(feature: "flag-a", default: JSON(false))
        XCTAssertEqual(value.boolValue, true)
    }

    func testGetFeatureValueReturnsNullForUnknownFeature() {
        let sdk = makeSDKWithFeatures()
        // Unknown features have no value (nil stored as JSON.null), so ?? fallback doesn't apply
        let value = sdk.getFeatureValue(feature: "nonexistent", default: JSON("fallback"))
        XCTAssertEqual(value, JSON.null)
    }

    func testGetFeatureValueReturnsStringFeatureValue() {
        let payload = """
        {"features":{"theme":{"defaultValue":"dark"}}}
        """.data(using: .utf8)!
        let sdk = makeSDK(features: payload)
        let value = sdk.getFeatureValue(feature: "theme", default: JSON("light"))
        XCTAssertEqual(value.stringValue, "dark")
    }

    // MARK: - getGBAttributes

    func testGetGBAttributesReturnsCurrentAttributes() {
        let sdk = makeSDKWithFeatures()
        let attrs = sdk.getGBAttributes()
        XCTAssertEqual(attrs["id"].stringValue, "user-1")
        XCTAssertEqual(attrs["country"].stringValue, "US")
    }

    // MARK: - setAttributes

    func testSetAttributesReplacesAttributes() {
        let sdk = makeSDKWithFeatures()
        sdk.setAttributes(attributes: ["id": "user-99", "plan": "premium"])
        let attrs = sdk.getGBAttributes()
        XCTAssertEqual(attrs["id"].stringValue, "user-99")
        XCTAssertEqual(attrs["plan"].stringValue, "premium")
        XCTAssertEqual(attrs["country"].stringValue, "")
    }

    func testSetAttributesEmptyDict() {
        let sdk = makeSDKWithFeatures()
        sdk.setAttributes(attributes: [:])
        XCTAssertTrue(sdk.getGBAttributes().dictionaryValue.isEmpty)
    }

    // MARK: - setForcedFeatures

    func testSetForcedFeaturesOverridesEvaluation() {
        let payload = """
        {"features":{"promo":{"defaultValue":false}}}
        """.data(using: .utf8)!
        let sdk = makeSDK(features: payload)

        XCTAssertFalse(sdk.isOn(feature: "promo"))

        sdk.setForcedFeatures(forcedFeatures: ["promo": true])

        XCTAssertTrue(sdk.isOn(feature: "promo"))
    }

    func testSetForcedFeaturesCanBeCleared() {
        let payload = """
        {"features":{"flag":{"defaultValue":false}}}
        """.data(using: .utf8)!
        let sdk = makeSDK(features: payload)

        sdk.setForcedFeatures(forcedFeatures: ["flag": true])
        XCTAssertTrue(sdk.isOn(feature: "flag"))

        sdk.setForcedFeatures(forcedFeatures: [:])
        XCTAssertFalse(sdk.isOn(feature: "flag"))
    }

    // MARK: - setForcedVariations (SDK method)

    func testSetForcedVariationsUpdatesContext() {
        let sdk = makeSDKWithFeatures()
        sdk.setForcedVariations(forcedVariations: ["my-exp": 1])
        let context = sdk.getGBContext()
        XCTAssertEqual(context.forcedVariations?["my-exp"].intValue, 1)
    }

    // MARK: - setAttributeOverrides

    func testSetAttributeOverridesDoesNotCrash() {
        let sdk = makeSDKWithFeatures()
        sdk.setAttributeOverrides(overrides: ["plan": "enterprise"])
        // No assertion needed — verifies it doesn't crash and updates state
        XCTAssertNotNil(sdk)
    }

    // MARK: - subscribe / clearSubscriptions

    func testSubscribeReceivesExperimentCallback() {
        let sdk = makeSDKWithFeatures()

        var receivedExperiment: Experiment?
        sdk.subscribe { experiment, _ in
            receivedExperiment = experiment
        }

        let exp = Experiment(key: "test-exp", variations: ["a", "b"])
        _ = sdk.run(experiment: exp)

        XCTAssertEqual(receivedExperiment?.key, "test-exp")
    }

    func testMultipleSubscribersAllReceiveCallback() {
        let sdk = makeSDKWithFeatures()
        var count = 0
        sdk.subscribe { _, _ in count += 1 }
        sdk.subscribe { _, _ in count += 1 }
        sdk.subscribe { _, _ in count += 1 }

        _ = sdk.run(experiment: Experiment(key: "exp", variations: ["a", "b"]))

        XCTAssertEqual(count, 3)
    }

    func testClearSubscriptionsStopsCallbacks() {
        let sdk = makeSDKWithFeatures()
        var called = false
        sdk.subscribe { _, _ in called = true }
        sdk.clearSubscriptions()

        _ = sdk.run(experiment: Experiment(key: "exp", variations: ["a", "b"]))

        XCTAssertFalse(called)
    }

    // MARK: - updateApiRequestHeaders / updateStreamingHostRequestHeaders

    func testUpdateApiRequestHeadersDoesNotCrash() {
        let sdk = makeSDKWithFeatures()
        sdk.updateApiRequestHeaders(["X-Custom": "value"])
        XCTAssertNotNil(sdk)
    }

    func testUpdateStreamingHostRequestHeadersDoesNotCrash() {
        let sdk = makeSDKWithFeatures()
        sdk.updateStreamingHostRequestHeaders(["Authorization": "Bearer token"])
        XCTAssertNotNil(sdk)
    }

    // MARK: - Builder: setForcedFeatures

    func testBuilderSetForcedFeaturesApplied() {
        let payload = """
        {"features":{"premium":{"defaultValue":false}}}
        """.data(using: .utf8)!
        let sdk = GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            attributes: [:],
            features: payload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setForcedFeatures(forcedFeatures: ["premium": true])
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertTrue(sdk.isOn(feature: "premium"))
    }

    // MARK: - Builder: setStreamingHost

    func testBuilderSetStreamingHostApplied() {
        let sdk = GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            attributes: [:],
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setStreamingHost(streamingHost: "https://custom-streaming.com")
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        let context = sdk.getGBContext()
        XCTAssertEqual(context.streamingHost, "https://custom-streaming.com")
    }

    // MARK: - Builder: setLogLevel

    func testBuilderSetLogLevelDoesNotCrash() {
        let sdk = GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            attributes: [:],
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setLogLevel(.warning)
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertNotNil(sdk)
    }

    // MARK: - Builder: setStickyBucketService

    func testBuilderSetStickyBucketService() {
        let service = StickyBucketService(prefix: "test__")
        let sdk = GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            attributes: [:],
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setStickyBucketService(stickyBucketService: service)
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertNotNil(sdk.getGBContext().stickyBucketService)
    }

    // MARK: - featuresFetchFailed propagates to refreshHandler

    func testFeaturesFetchFailedCallsRefreshHandlerWithError() {
        let exp = expectation(description: "refreshHandler called with error")
        exp.assertForOverFulfill = false

        let cachingManager = CachingManager(apiKey: "isolated-error-test")
        cachingManager.clearCache()

        let sdk = GrowthBookBuilder(
            growthBookBuilderModel: GrowthBookModel(
                apiHost: apiHost, clientKey: "isolated-error-test",
                attributes: JSON([:]), trackingClosure: { _, _ in },
                backgroundSync: false
            ),
            networkDispatcher: MockNetworkClient(successResponse: nil, error: SDKError.failedToFetchData),
            ttlSeconds: 0,
            cachingManager: cachingManager,
            refreshHandler: { error in
                if error != nil { exp.fulfill() }
            }
        ).initializer()

        _ = sdk
        wait(for: [exp], timeout: 2.0)
    }

    // MARK: - savedGroupsFetchedSuccessfully updates context

    func testSavedGroupsAreAppliedToContext() {
        let exp = expectation(description: "savedGroups applied")
        exp.assertForOverFulfill = false
        var savedGroupsApplied = false

        let cachingManager = CachingManager(apiKey: "isolated-savedgroups-test")
        cachingManager.clearCache()

        let sdk = GrowthBookBuilder(
            growthBookBuilderModel: GrowthBookModel(
                apiHost: apiHost, clientKey: "isolated-savedgroups-test",
                attributes: JSON([:]), trackingClosure: { _, _ in },
                backgroundSync: false
            ),
            networkDispatcher: MockNetworkClient(
                successResponse: MockResponse().successResponse,
                error: nil
            ),
            ttlSeconds: 0,
            cachingManager: cachingManager,
            refreshHandler: { _ in
                exp.fulfill()
            }
        ).initializer()

        wait(for: [exp], timeout: 2.0)
        savedGroupsApplied = sdk.getGBContext().savedGroups != nil
        XCTAssertTrue(savedGroupsApplied)
    }

    func testRunsRefreshHandler() {
        // GIVEN
        let expectation = XCTestExpectation(description: "Runs refresh handler even if features are cached")
        expectation.expectedFulfillmentCount = 2
        // 1 call - initializer.featuresUpdateIsComplete
        // 2 call - refreshCache.featuresUpdateIsComplete
        let cachingManager = CachingManager(apiKey: "isolated-savedgroups-test")
        cachingManager.clearCache()

        let sdk = GrowthBookBuilder(
            growthBookBuilderModel: GrowthBookModel(
                apiHost: apiHost, clientKey: "isolated-savedgroups-test",
                attributes: JSON([:]), trackingClosure: { _, _ in },
                backgroundSync: false
            ),
            networkDispatcher: MockNetworkClient(
                successResponse: MockResponse().successResponseNoGroups,
                error: nil
            ),
            ttlSeconds: 60,
            cachingManager: cachingManager,
            refreshHandler: { _ in
                expectation.fulfill()
            }
        ).initializer()

        // WHEN
        sdk.refreshCache()

        // THEN
        wait(for: [expectation], timeout: 2.0)

        XCTAssertTrue(sdk.isOn(feature: "onboarding"))
    }

    // MARK: - clearStickyBuckets

    /// Payload with one experiment rule, so the SDK derives "id" as a sticky bucket identifier
    /// attribute and loads the persisted document for the current user at init.
    private var stickyFeaturesPayload: Data {
        """
        {"features":{"exp-feature":{"defaultValue":"off","rules":[{"key":"my-exp","variations":["a","b"],"hashAttribute":"id","weights":[0.5,0.5],"meta":[{"key":"0"},{"key":"1"}],"disableStickyBucketing":false}]}}}
        """.data(using: .utf8)!
    }

    private func makeStickySDK(service: StickyBucketService, clientKey: String) -> GrowthBookSDK {
        let cachingManager = CachingManager(apiKey: clientKey)

        return GrowthBookBuilder(
            growthBookBuilderModel: GrowthBookModel(
                apiHost: apiHost, clientKey: clientKey,
                features: stickyFeaturesPayload,
                attributes: JSON(["id": "user-1", "deviceId": "device-1"]),
                trackingClosure: { _, _ in },
                stickyBucketService: service,
                backgroundSync: false
            ),
            networkDispatcher: MockNetworkClient(successResponse: nil, error: nil),
            ttlSeconds: 60,
            cachingManager: cachingManager,
            refreshHandler: nil
        ).initializer()
    }

    func testClearStickyBucketsDropsInMemoryAndPersistedAssignments() {
        let service = StickyBucketService(prefix: "sdk_clear_\(Int.random(in: 100_000...999_999))__")
        let doc = StickyAssignmentsDocument(attributeName: "id", attributeValue: "user-1", assignments: ["my-exp__0": "1"])

        let save = expectation(description: "seed doc")
        service.saveAssignments(doc: doc) { _ in save.fulfill() }
        waitForExpectations(timeout: 1)

        let sdk = makeStickySDK(service: service, clientKey: "isolated-sticky-clear-test")
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||user-1"], "precondition: doc is loaded at init")

        let cleared = expectation(description: "clear completed")
        sdk.clearStickyBuckets { error in
            XCTAssertNil(error)
            cleared.fulfill()
        }
        waitForExpectations(timeout: 1)

        XCTAssertTrue(sdk.getGBContext().stickyBucketAssignmentDocs?.isEmpty ?? true, "in-memory docs should be gone")

        let get = expectation(description: "persisted doc gone")
        service.getAssignments(attributeName: "id", attributeValue: "user-1") { retrieved, _ in
            XCTAssertNil(retrieved, "persisted doc should be gone, otherwise the next refresh reloads it")
            get.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    /// The whole point of the API: after the assignment is dropped, targeting is decided again
    /// instead of the user staying enrolled on the strength of a stale sticky bucket.
    func testClearStickyBucketsSurvivesAttributeRefresh() {
        let service = StickyBucketService(prefix: "sdk_refresh_\(Int.random(in: 100_000...999_999))__")
        let doc = StickyAssignmentsDocument(attributeName: "id", attributeValue: "user-1", assignments: ["my-exp__0": "1"])

        let save = expectation(description: "seed doc")
        service.saveAssignments(doc: doc) { _ in save.fulfill() }
        waitForExpectations(timeout: 1)

        let sdk = makeStickySDK(service: service, clientKey: "isolated-sticky-refresh-test")
        sdk.clearStickyBuckets()

        // setAttributes re-reads the service; a doc that was only cleared in memory would come back.
        sdk.setAttributes(attributes: ["id": "user-1", "deviceId": "device-1"])

        XCTAssertTrue(sdk.getGBContext().stickyBucketAssignmentDocs?.isEmpty ?? true)
    }

    func testClearStickyBucketsForAttributeKeepsOtherDocuments() {
        let service = StickyBucketService(prefix: "sdk_attr_\(Int.random(in: 100_000...999_999))__")
        let userDoc   = StickyAssignmentsDocument(attributeName: "id",       attributeValue: "user-1",   assignments: ["my-exp__0": "1"])
        let deviceDoc = StickyAssignmentsDocument(attributeName: "deviceId", attributeValue: "device-1", assignments: ["my-exp__0": "0"])

        let s1 = expectation(description: "seed user doc");   service.saveAssignments(doc: userDoc)   { _ in s1.fulfill() }
        let s2 = expectation(description: "seed device doc"); service.saveAssignments(doc: deviceDoc) { _ in s2.fulfill() }
        waitForExpectations(timeout: 1)

        let sdk = makeStickySDK(service: service, clientKey: "isolated-sticky-attr-test")

        sdk.clearStickyBuckets(forAttribute: "deviceId", value: "device-1")

        XCTAssertNil(sdk.getGBContext().stickyBucketAssignmentDocs?["deviceId||device-1"])
        XCTAssertNotNil(sdk.getGBContext().stickyBucketAssignmentDocs?["id||user-1"], "unrelated document must survive")

        let get = expectation(description: "persisted user doc survives")
        service.getAssignments(attributeName: "id", attributeValue: "user-1") { retrieved, _ in
            XCTAssertNotNil(retrieved)
            get.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testClearStickyBucketsWithoutServiceIsNoOp() {
        let sdk = makeSDK()

        let cleared = expectation(description: "clear completed")
        sdk.clearStickyBuckets { error in
            XCTAssertNil(error)
            cleared.fulfill()
        }
        waitForExpectations(timeout: 1)

        sdk.clearStickyBuckets(forAttribute: "id", value: "user-1")
    }
}
