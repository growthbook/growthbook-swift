import XCTest
@testable import GrowthBook

/// Covers the tracking plugin's missing features from growthbook-swift#193: deduplication,
/// `logEvent`, and the switch that turns feature usage events off.
final class TrackingPluginFeaturesTests: XCTestCase {

    // MARK: - Helpers

    /// Collects every event that actually reached the wire, across all batches.
    private final class Recorder {
        private let lock = NSLock()
        private var _events: [[String: Any]] = []

        var events: [[String: Any]] { lock.lock(); defer { lock.unlock() }; return _events }
        var eventNames: [String] { events.compactMap { $0["event_name"] as? String } }

        func record(_ request: URLRequest) {
            guard
                let body = request.httpBody,
                let batch = try? JSONSerialization.jsonObject(with: body) as? [[String: Any]]
            else { return }
            lock.lock(); defer { lock.unlock() }
            _events.append(contentsOf: batch)
        }
    }

    /// `batchTimeout` is long so nothing is sent until `close()`, keeping the assertions about
    /// what was buffered rather than about timing.
    private func makePlugin(
        dedupeCacheSize: Int = GrowthBookTrackingPlugin.Config.defaultDedupeCacheSize,
        enableFeatureUsageEvents: Bool = true,
        into recorder: Recorder
    ) -> GrowthBookTrackingPlugin {
        GrowthBookTrackingPlugin(
            config: .init(
                batchSize: 10_000,
                batchTimeout: 600,
                dedupeCacheSize: dedupeCacheSize,
                enableFeatureUsageEvents: enableFeatureUsageEvents
            )
        ) { request, completion in
            recorder.record(request)
            completion(true)
        }
    }

    private func featureResult(value: JSON = JSON(true), ruleId: String = "rule-1") -> FeatureResult {
        FeatureResult(value: value, isOn: true, source: "force",
                      experiment: nil, result: nil, ruleId: ruleId)
    }

    /// Experiment keys are unique per test: `ExperimentHelper.shared` dedupes tracked exposures in
    /// a process-wide set, so two tests sharing a key would silence each other.
    private func experiment(key: String) -> Experiment {
        Experiment(key: key, variations: [JSON(0), JSON(1)])
    }

    private func experimentResult(key: String = "1", hashValue: String = "user-1") -> ExperimentResult {
        ExperimentResult(inExperiment: true, variationId: 1, value: JSON(1),
                         hashAttribute: "id", hashValue: hashValue, key: key)
    }

    // MARK: - Deduplication

    /// The reported problem: a flag read on every screen queues an identical event each time.
    func testRepeatedIdenticalFeatureEvaluationsAreSentOnce() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        for _ in 0..<5 {
            plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        }
        plugin.close()

        XCTAssertEqual(recorder.eventNames, ["Feature Evaluated"])
    }

    /// The issue text only names feature evaluations, but the reference SDK dedupes exposures too,
    /// and an exposure repeats just as readily.
    func testRepeatedIdenticalExperimentExposuresAreSentOnce() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        for _ in 0..<5 {
            plugin.onExperimentViewed(experiment: experiment(key: "dedupe-exposure"),
                                      result: experimentResult(), attributes: nil)
        }
        plugin.close()

        XCTAssertEqual(recorder.eventNames, ["Experiment Viewed"])
    }

    /// Deduping must key on what the event says, not merely on the feature it is about —
    /// otherwise a flag that flips value would report only its first state.
    func testADifferentEvaluationOfTheSameFeatureIsNotADuplicate() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(value: JSON(true)), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(value: JSON(false)), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(value: JSON(true), ruleId: "rule-2"), attributes: nil)
        plugin.close()

        XCTAssertEqual(recorder.events.count, 3)
    }

    /// Attributes are deliberately outside the key: a feature evaluation carries no unit identity,
    /// so keying on them would defeat deduping for any app that updates attributes.
    func testAttributeChangesDoNotMakeAnEvaluationLookNew() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: JSON(["plan": "free"]))
        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: JSON(["plan": "pro"]))
        plugin.close()

        XCTAssertEqual(recorder.events.count, 1)
    }

    func testDedupingCanBeTurnedOff() {
        let recorder = Recorder()
        let plugin = makePlugin(dedupeCacheSize: 0, into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        for _ in 0..<4 {
            plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        }
        plugin.close()

        XCTAssertEqual(recorder.events.count, 4, "A zero cache must send everything, not drop everything")
    }

    /// The cache is bounded, so an evaluation seen long enough ago is reported again rather than
    /// suppressed forever.
    func testAnEvaluationPushedOutOfTheCacheIsReportedAgain() {
        let recorder = Recorder()
        let plugin = makePlugin(dedupeCacheSize: 2, into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "flag-a", result: featureResult(), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "flag-b", result: featureResult(), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "flag-c", result: featureResult(), attributes: nil)
        // flag-a is now the evicted one.
        plugin.onFeatureEvaluated(featureKey: "flag-a", result: featureResult(), attributes: nil)
        plugin.close()

        XCTAssertEqual(recorder.events.count, 4)
    }

    /// What makes the cache an LRU rather than a queue: re-seeing an entry has to protect it from
    /// eviction, or a flag read constantly would still be re-reported once the cache turned over.
    func testSeeingAnEvaluationAgainProtectsItFromEviction() {
        let recorder = Recorder()
        let plugin = makePlugin(dedupeCacheSize: 2, into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "flag-a", result: featureResult(), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "flag-b", result: featureResult(), attributes: nil)
        // Refreshes flag-a, making flag-b the oldest.
        plugin.onFeatureEvaluated(featureKey: "flag-a", result: featureResult(), attributes: nil)
        // Evicts flag-b, not flag-a.
        plugin.onFeatureEvaluated(featureKey: "flag-c", result: featureResult(), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "flag-a", result: featureResult(), attributes: nil)
        plugin.close()

        let features = recorder.events.compactMap {
            ($0["properties_json"] as? [String: Any])?["feature"] as? String
        }
        XCTAssertEqual(features, ["flag-a", "flag-b", "flag-c"],
                       "flag-a was refreshed and must not have been evicted")
    }

    // MARK: - Failed sends

    /// The cache records an evaluation when it is accepted, before anything is known about whether
    /// it will arrive. A batch dropped while the device is offline would otherwise suppress its
    /// events for good — and because re-evaluating one refreshes its place in the cache, it would
    /// never age out either, so a single offline moment ends a flag's reporting for the session.
    func testADroppedBatchDoesNotSuppressItsEventsForEver() {
        var attempts = 0
        var succeeds = false
        let plugin = GrowthBookTrackingPlugin(
            config: .init(batchSize: 1000, batchTimeout: 600)
        ) { _, finish in
            attempts += 1
            finish(succeeds)
        }
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.flush()
        XCTAssertEqual(attempts, 1)

        succeeds = true
        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.flush()

        XCTAssertEqual(attempts, 2, "The evaluation was never delivered, so it must be sent again")
    }

    /// The mirror image: a batch that did land must stay suppressed, or deduping would do nothing.
    func testADeliveredBatchKeepsItsEventsSuppressed() {
        var attempts = 0
        let plugin = GrowthBookTrackingPlugin(
            config: .init(batchSize: 1000, batchTimeout: 600)
        ) { _, finish in
            attempts += 1
            finish(true)
        }
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.flush()
        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.flush()

        XCTAssertEqual(attempts, 1)
    }

    /// Only the failed batch's own keys come back; a flag delivered earlier stays suppressed.
    func testOnlyTheFailedBatchGetsItsKeysBack() {
        var attempts = 0
        var succeeds = true
        let plugin = GrowthBookTrackingPlugin(
            config: .init(batchSize: 1000, batchTimeout: 600)
        ) { _, finish in
            attempts += 1
            finish(succeeds)
        }
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "delivered", result: featureResult(), attributes: nil)
        plugin.flush()

        succeeds = false
        plugin.onFeatureEvaluated(featureKey: "dropped", result: featureResult(), attributes: nil)
        plugin.flush()

        succeeds = true
        plugin.onFeatureEvaluated(featureKey: "delivered", result: featureResult(), attributes: nil)
        plugin.onFeatureEvaluated(featureKey: "dropped", result: featureResult(), attributes: nil)
        plugin.flush()

        // 1: delivered. 2: dropped. 3: the retry of dropped alone — `delivered` is still suppressed.
        XCTAssertEqual(attempts, 3)
    }

    // MARK: - Shutdown

    /// `PluginRegistry` drops the lock before dispatching, so an evaluation can pass its open check
    /// and reach the plugin after a concurrent `close()` has finished. The plugin has to be inert
    /// on its own account — the registry's latch cannot be the only defence.
    func testThePluginIgnoresEventsAdmittedAfterItsOwnClose() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")
        plugin.close()

        plugin.onFeatureEvaluated(featureKey: "after-close", result: featureResult(), attributes: nil)
        plugin.onExperimentViewed(experiment: experiment(key: "after-close-exposure"),
                                  result: experimentResult(), attributes: nil)
        plugin.logEvent(eventName: "after_close", properties: nil, attributes: nil)
        // A second close would send anything that had been buffered by the calls above.
        plugin.close()

        XCTAssertTrue(recorder.events.isEmpty, "A closed plugin must not buffer or send anything")
    }

    // MARK: - logEvent

    func testLogEventReachesTheWireWithItsNameAndProperties() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.logEvent(eventName: "checkout_completed",
                        properties: JSON(["total": 42]),
                        attributes: JSON(["user_id": "u-1", "plan": "pro"]))
        plugin.close()

        let event = recorder.events.first
        XCTAssertEqual(event?["event_name"] as? String, "checkout_completed")
        XCTAssertEqual((event?["properties_json"] as? [String: Any])?["total"] as? Int, 42)
        XCTAssertEqual(event?["user_id"] as? String, "u-1",
                       "Custom events share the envelope, so identity is promoted here too")
        XCTAssertEqual((event?["context_json"] as? [String: Any])?["plan"] as? String, "pro")
    }

    /// An event with no fields still has to be a record: a null `properties_json` is a different
    /// shape from an empty one.
    func testLogEventWithoutPropertiesSendsAnEmptyObject() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.logEvent(eventName: "app_opened", properties: nil, attributes: nil)
        plugin.close()

        let properties = recorder.events.first?["properties_json"] as? [String: Any]
        XCTAssertNotNil(properties)
        XCTAssertTrue(properties?.isEmpty == true)
    }

    /// The app decided to send each of these, so a repeat is a second occurrence rather than a
    /// redundant re-evaluation.
    func testRepeatedCustomEventsAreNeverDeduplicated() {
        let recorder = Recorder()
        let plugin = makePlugin(into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        for _ in 0..<3 {
            plugin.logEvent(eventName: "button_tapped", properties: JSON(["id": "buy"]), attributes: nil)
        }
        plugin.close()

        XCTAssertEqual(recorder.events.count, 3)
    }

    // MARK: - enableFeatureUsageEvents

    func testFeatureUsageEventsCanBeTurnedOff() {
        let recorder = Recorder()
        let plugin = makePlugin(enableFeatureUsageEvents: false, into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.close()

        XCTAssertTrue(recorder.events.isEmpty)
    }

    /// Turning usage events off must not cost the app its experiment data — that is the whole
    /// point of the switch being separate from disabling the plugin.
    func testTurningUsageEventsOffKeepsExposuresAndCustomEvents() {
        let recorder = Recorder()
        let plugin = makePlugin(enableFeatureUsageEvents: false, into: recorder)
        plugin.initialize(clientKey: "sdk-test")

        plugin.onFeatureEvaluated(featureKey: "my-flag", result: featureResult(), attributes: nil)
        plugin.onExperimentViewed(experiment: experiment(key: "usage-off-exposure"),
                                  result: experimentResult(), attributes: nil)
        plugin.logEvent(eventName: "app_opened", properties: nil, attributes: nil)
        plugin.close()

        XCTAssertEqual(recorder.eventNames, ["Experiment Viewed", "app_opened"])
    }

    // MARK: - SDK facade

    func testSdkLogEventReachesRegisteredPlugins() {
        final class CapturingPlugin: GrowthBookPlugin {
            var eventName: String?
            var properties: JSON?
            var attributes: JSON?
            func logEvent(eventName: String, properties: JSON?, attributes: JSON?) {
                self.eventName = eventName
                self.properties = properties
                self.attributes = attributes
            }
        }

        let plugin = CapturingPlugin()
        let sdk = GrowthBookBuilder(
            features: "{\"features\":{}}".data(using: .utf8)!,
            attributes: ["id": "user-1"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .addPlugin(plugin)
        .initializer()

        sdk.logEvent("checkout_completed", properties: ["total": 42])

        XCTAssertEqual(plugin.eventName, "checkout_completed")
        XCTAssertEqual(plugin.properties?["total"].int, 42)
        XCTAssertEqual(plugin.attributes?["id"].string, "user-1",
                       "The event has to carry the attributes current at the time it was logged")
    }

    /// `close` promises nothing is recorded afterwards, and a custom event is a recording like any
    /// other — the registry's latch has to cover `logEvent` too.
    func testSdkLogEventStopsAfterClose() {
        final class CountingPlugin: GrowthBookPlugin {
            var count = 0
            func logEvent(eventName: String, properties: JSON?, attributes: JSON?) { count += 1 }
        }

        let plugin = CountingPlugin()
        let sdk = GrowthBookBuilder(
            features: "{\"features\":{}}".data(using: .utf8)!,
            attributes: ["id": "user-1"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .addPlugin(plugin)
        .initializer()

        sdk.logEvent("before_close")
        sdk.close()
        sdk.logEvent("after_close")

        XCTAssertEqual(plugin.count, 1)
    }

    // MARK: - Objective-C surface

    /// `GrowthBookTrackingPlugin()` has to keep resolving for Swift callers now that an @objc
    /// `init()` sits alongside `init(config:)` with its defaulted argument.
    func testTheNoArgumentInitialiserStillCarriesTheDefaults() {
        let plugin = GrowthBookTrackingPlugin()
        XCTAssertNotNil(plugin)

        let config = GrowthBookTrackingPlugin.Config()
        XCTAssertEqual(config.dedupeCacheSize, 1000)
        XCTAssertTrue(config.enableFeatureUsageEvents)
        XCTAssertEqual(config.ingestorHost, "https://us1.gb-ingest.com")
    }

    /// `addPlugin` takes a Swift-only protocol, so Objective-C apps had no way to register the
    /// built-in plugin at all.
    func testTrackingPluginCanBeRegisteredThroughTheObjectiveCEntryPoint() {
        let plugin = GrowthBookTrackingPlugin(
            ingestorHost: GrowthBookTrackingPlugin.Config.defaultIngestorHost,
            batchSize: 10,
            batchTimeout: 5,
            dedupeCacheSize: 100,
            enableFeatureUsageEvents: false
        )

        let sdk = GrowthBookBuilder(
            features: "{\"features\":{}}".data(using: .utf8)!,
            attributes: ["id": "user-1"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .addTrackingPlugin(plugin)
        .initializer()

        // Reaching the plugin at all is the point; close() would fail if it were never registered.
        sdk.close()
    }
}

// MARK: - DedupeCache

final class DedupeCacheTests: XCTestCase {

    func testReportsADuplicateOnlyOnTheSecondSighting() {
        let cache = DedupeCache(capacity: 10)

        XCTAssertFalse(cache.insertAndReportDuplicate("a"))
        XCTAssertTrue(cache.insertAndReportDuplicate("a"))
    }

    func testNeverGrowsBeyondItsCapacity() {
        let cache = DedupeCache(capacity: 3)

        for index in 0..<100 {
            _ = cache.insertAndReportDuplicate("key-\(index)")
        }

        XCTAssertEqual(cache.count, 3)
    }

    func testEvictsTheLeastRecentlyUsedEntry() {
        let cache = DedupeCache(capacity: 2)

        _ = cache.insertAndReportDuplicate("a")
        _ = cache.insertAndReportDuplicate("b")
        _ = cache.insertAndReportDuplicate("a")   // refreshes a, so b is now oldest
        _ = cache.insertAndReportDuplicate("c")   // evicts b

        XCTAssertTrue(cache.insertAndReportDuplicate("a"), "a was refreshed and must survive")
        XCTAssertFalse(cache.insertAndReportDuplicate("b"), "b was the least recently used")
    }

    /// Single-entry and zero capacities are the cases most likely to walk off the end of the list.
    func testHandlesDegenerateCapacities() {
        let single = DedupeCache(capacity: 1)
        XCTAssertFalse(single.insertAndReportDuplicate("a"))
        XCTAssertTrue(single.insertAndReportDuplicate("a"))
        XCTAssertFalse(single.insertAndReportDuplicate("b"))
        XCTAssertFalse(single.insertAndReportDuplicate("a"), "a was evicted by b")
        XCTAssertEqual(single.count, 1)

        let disabled = DedupeCache(capacity: 0)
        XCTAssertFalse(disabled.insertAndReportDuplicate("a"))
        XCTAssertFalse(disabled.insertAndReportDuplicate("a"))
        XCTAssertEqual(disabled.count, 0)
    }

    /// A negative capacity would otherwise make every `count > capacity` check evict immediately.
    func testTreatsANegativeCapacityAsDisabled() {
        let cache = DedupeCache(capacity: -5)

        XCTAssertFalse(cache.insertAndReportDuplicate("a"))
        XCTAssertFalse(cache.insertAndReportDuplicate("a"))
    }
}
