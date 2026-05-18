import XCTest
@testable import GrowthBook

// MARK: - MockPlugin

/// Records all plugin calls for use in integration assertions.
final class MockPlugin: GrowthBookPlugin {
    private let lock = NSLock()

    private var _initializedWith: String?
    var initializedWith: String? { lock.lock(); defer { lock.unlock() }; return _initializedWith }

    private var _experimentCallCount = 0
    var experimentCallCount: Int { lock.lock(); defer { lock.unlock() }; return _experimentCallCount }

    private var _featureCallCount = 0
    var featureCallCount: Int { lock.lock(); defer { lock.unlock() }; return _featureCallCount }

    private var _closeCalled = false
    var closeCalled: Bool { lock.lock(); defer { lock.unlock() }; return _closeCalled }

    func initialize(clientKey: String) {
        lock.lock(); defer { lock.unlock() }
        _initializedWith = clientKey
    }
    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        lock.lock(); defer { lock.unlock() }
        _experimentCallCount += 1
    }
    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        lock.lock(); defer { lock.unlock() }
        _featureCallCount += 1
    }
    func close() {
        lock.lock(); defer { lock.unlock() }
        _closeCalled = true
    }
}


// MARK: - Plugin integration tests

/// Tests that MockPlugin receives the correct lifecycle and evaluation events via GrowthBookSDK.
final class GrowthBookPluginIntegrationTests: XCTestCase {

    private let clientKey = "sdk-test-key"

    private func makeSDK(plugins: [GrowthBookPlugin] = [], features: Data? = nil) -> GrowthBookSDK {
        var builder = GrowthBookBuilder(
            apiHost: "https://host.com",
            clientKey: clientKey,
            attributes: ["id": "user-1"],
            features: features,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 60
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        for plugin in plugins { builder = builder.addPlugin(plugin) }
        return builder.initializer()
    }

    private func featuresPayload() -> Data {
        #"{"features":{"flag-a":{"defaultValue":true}}}"#.data(using: .utf8)!
    }

    // MARK: - Lifecycle

    func testPluginReceivesInitialize() {
        let plugin = MockPlugin()
        _ = makeSDK(plugins: [plugin])
        XCTAssertEqual(plugin.initializedWith, clientKey)
    }

    func testPluginCloseCalledOnSDKDeinit() {
        let plugin = MockPlugin()
        autoreleasepool { _ = makeSDK(plugins: [plugin]) }
        XCTAssertTrue(plugin.closeCalled)
    }

    // MARK: - Experiment events

    func testPluginReceivesOnExperimentViewed() {
        let plugin = MockPlugin()
        let sdk = makeSDK(plugins: [plugin])
        // UUID key avoids ExperimentHelper deduplication across test runs
        let exp = Experiment(key: "plugin-exp-\(UUID().uuidString)", variations: [JSON(0), JSON(1)], coverage: 1.0)
        sdk.run(experiment: exp)
        XCTAssertEqual(plugin.experimentCallCount, 1)
    }

    func testPluginNotCalledWhenUserNotInExperiment() {
        let plugin = MockPlugin()
        let sdk = makeSDK(plugins: [plugin])
        // coverage = 0 → user never assigned → inExperiment = false
        let exp = Experiment(key: "plugin-exp-\(UUID().uuidString)", variations: [JSON(0), JSON(1)], coverage: 0.0)
        sdk.run(experiment: exp)
        XCTAssertEqual(plugin.experimentCallCount, 0)
    }

    // MARK: - Feature events

    func testPluginReceivesOnFeatureEvaluated() {
        let plugin = MockPlugin()
        let sdk = makeSDK(plugins: [plugin], features: featuresPayload())
        _ = sdk.evalFeature(id: "flag-a")
        XCTAssertEqual(plugin.featureCallCount, 1)
    }

    func testPluginReceivesFeatureEvaluatedForUnknownFeature() {
        let plugin = MockPlugin()
        let sdk = makeSDK(plugins: [plugin], features: featuresPayload())
        _ = sdk.evalFeature(id: "nonexistent")
        XCTAssertEqual(plugin.featureCallCount, 1)
    }

    // MARK: - Multiple plugins

    func testMultiplePluginsAllReceiveEvents() {
        let p1 = MockPlugin()
        let p2 = MockPlugin()
        let sdk = makeSDK(plugins: [p1, p2], features: featuresPayload())
        _ = sdk.evalFeature(id: "flag-a")
        XCTAssertEqual(p1.featureCallCount, 1)
        XCTAssertEqual(p2.featureCallCount, 1)
    }

    func testMultiplePluginsAllInitialized() {
        let p1 = MockPlugin()
        let p2 = MockPlugin()
        _ = makeSDK(plugins: [p1, p2])
        XCTAssertEqual(p1.initializedWith, clientKey)
        XCTAssertEqual(p2.initializedWith, clientKey)
    }
}

// MARK: - GrowthBookTrackingPlugin unit tests

final class GrowthBookTrackingPluginTests: XCTestCase {

    private func makePlugin(
        batchSize: Int = GrowthBookTrackingPlugin.Config.defaultBatchSize,
        batchTimeout: TimeInterval = GrowthBookTrackingPlugin.Config.defaultBatchTimeout,
        onRequest: ((URLRequest) -> Void)? = nil
    ) -> GrowthBookTrackingPlugin {
        GrowthBookTrackingPlugin(config: .init(batchSize: batchSize, batchTimeout: batchTimeout)) { request, completion in
            onRequest?(request)
            completion()
        }
    }

    private func makeExperiment() -> Experiment {
        Experiment(key: "test-exp", variations: [JSON(0), JSON(1)])
    }

    private func makeExperimentResult() -> ExperimentResult {
        ExperimentResult(inExperiment: true, variationId: 1, value: JSON(1),
                         hashAttribute: "id", hashValue: "user-1", key: "1")
    }

    // MARK: - No-op without clientKey

    func testNoOpWithEmptyClientKey() {
        var requestCount = 0
        let plugin = makePlugin(batchSize: 1) { _ in requestCount += 1 }
        plugin.initialize(clientKey: "")
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        plugin.close()
        XCTAssertEqual(requestCount, 0)
    }

    // MARK: - Batch size flush

    func testFlushWhenBatchSizeReached() {
        let expectation = expectation(description: "flush on batch size")
        let plugin = makePlugin(batchSize: 3, batchTimeout: 60) { request in
            XCTAssertTrue(request.url?.absoluteString.contains("client_key=sdk-test") == true)
            let events = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [[String: Any]]
            XCTAssertEqual(events.count, 3)
            expectation.fulfill()
        }
        plugin.initialize(clientKey: "sdk-test")
        for _ in 0..<3 {
            plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        }
        wait(for: [expectation], timeout: 3.0)
    }

    func testNoFlushBeforeBatchSizeReached() {
        var requestCount = 0
        let plugin = makePlugin(batchSize: 5, batchTimeout: 60) { _ in requestCount += 1 }
        plugin.initialize(clientKey: "sdk-test")
        for _ in 0..<4 {
            plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        }
        Thread.sleep(forTimeInterval: 0.1)
        XCTAssertEqual(requestCount, 0)
        plugin.close()
    }

    // MARK: - Timer flush

    func testTimerTriggersFlush() {
        let expectation = expectation(description: "timer flush")
        let plugin = makePlugin(batchSize: 100, batchTimeout: 0.1) { _ in expectation.fulfill() }
        plugin.initialize(clientKey: "sdk-test")
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        wait(for: [expectation], timeout: 3.0)
        withExtendedLifetime(plugin) {}
    }

    // MARK: - close() synchronous flush

    func testCloseFlushesSynchronously() {
        var requestSent = false
        let plugin = makePlugin(batchSize: 100, batchTimeout: 60) { _ in requestSent = true }
        plugin.initialize(clientKey: "sdk-test")
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)

        XCTAssertFalse(requestSent, "no request before close()")
        plugin.close()
        XCTAssertTrue(requestSent, "close() must flush synchronously")
    }

    func testCloseWithNoEventsDoesNotSendRequest() {
        var requestCount = 0
        let plugin = makePlugin() { _ in requestCount += 1 }
        plugin.initialize(clientKey: "sdk-test")
        plugin.close()
        XCTAssertEqual(requestCount, 0)
    }

    // MARK: - Network failure

    func testNetworkFailureDoesNotCrash() {
        // Simulate a handler that never calls completion — close() must not deadlock.
        // We use a short timeout so flushSync doesn't block indefinitely in prod code.
        // Here the sendHandler always calls completion, so this just verifies no crash.
        let plugin = makePlugin(batchSize: 100, batchTimeout: 60)
        plugin.initialize(clientKey: "sdk-test")
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        plugin.close()
    }

    // MARK: - Request format

    func testRequestSentToCorrectEndpoint() {
        let expectation = expectation(description: "correct endpoint")
        let plugin = makePlugin(batchSize: 1) { request in
            XCTAssertEqual(request.url?.absoluteString, "\(GrowthBookTrackingPlugin.Config.defaultIngestorHost)/track?client_key=sdk-test")
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertTrue(request.value(forHTTPHeaderField: "User-Agent")?.hasPrefix("growthbook-swift-sdk/") == true)
            expectation.fulfill()
        }
        plugin.initialize(clientKey: "sdk-test")
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: nil)
        wait(for: [expectation], timeout: 3.0)
    }

    func testFeatureEvaluatedEventIncludedInPayload() {
        let expectation = expectation(description: "feature event in payload")
        let plugin = makePlugin(batchSize: 1) { request in
            let events = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [[String: Any]]
            XCTAssertEqual(events.first?["event_name"] as? String, "Feature Evaluated")
            let props = events.first?["properties"] as? [String: Any]
            XCTAssertEqual(props?["feature"] as? String, "my-feature")
            expectation.fulfill()
        }
        plugin.initialize(clientKey: "sdk-test")
        let featureResult = FeatureResult(value: JSON(true), isOn: true, source: "defaultValue")
        plugin.onFeatureEvaluated(featureKey: "my-feature", result: featureResult, attributes: nil)
        wait(for: [expectation], timeout: 3.0)
    }

    func testAttributesIncludedInEventPayload() {
        let expectation = expectation(description: "attributes in payload")
        let plugin = makePlugin(batchSize: 1) { request in
            let events = try! JSONSerialization.jsonObject(with: request.httpBody!) as! [[String: Any]]
            let attrs = events.first?["attributes"] as? [String: Any]
            XCTAssertEqual(attrs?["id"] as? String, "user-1")
            XCTAssertEqual(attrs?["plan"] as? String, "pro")
            XCTAssertEqual(attrs?["sdk_language"] as? String, "swift")
            XCTAssertNotNil(attrs?["sdk_version"])
            expectation.fulfill()
        }
        plugin.initialize(clientKey: "sdk-test")
        let attrs = JSON(["id": "user-1", "plan": "pro"])
        plugin.onExperimentViewed(experiment: makeExperiment(), result: makeExperimentResult(), attributes: attrs)
        wait(for: [expectation], timeout: 3.0)
        withExtendedLifetime(plugin) {}
    }
}
