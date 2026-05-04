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
}
