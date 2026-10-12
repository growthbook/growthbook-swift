import XCTest
@testable import GrowthBook

/// Covers the ingest payloads and the flush path, reported in growthbook-swift#193.
///
/// The payload cases are about analysis joining on the variation key: an exposure that carries the
/// array index instead arrives intact and simply never matches the experiment it belongs to, which
/// looks like an experiment with no traffic rather than like a bug.
class TrackingPluginParityTests: XCTestCase {

    private func encoded(_ value: Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(AnyEncodable(value))
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    private func properties(of value: Encodable) throws -> [String: Any] {
        try XCTUnwrap(try encoded(value)["properties"] as? [String: Any])
    }

    /// Minimal type-erasing wrapper so both event structs can go through one helper.
    private struct AnyEncodable: Encodable {
        private let encodeTo: (Encoder) throws -> Void
        init(_ wrapped: Encodable) { encodeTo = wrapped.encode(to:) }
        func encode(to encoder: Encoder) throws { try encodeTo(encoder) }
    }

    private func experimentResult(
        variationId: Int = 1,
        key: String = "treatment",
        hashAttribute: String? = "id",
        valueHash: String? = "user-1"
    ) -> ExperimentResult {
        ExperimentResult(
            inExperiment: true,
            variationId: variationId,
            value: JSON("b"),
            hashAttribute: hashAttribute,
            hashValue: valueHash,
            key: key,
            name: nil,
            bucket: nil,
            passthrough: nil,
            hashUsed: true,
            featureId: nil
        )
    }

    // MARK: - Experiment Viewed

    func testExperimentEventSendsTheVariationKeyNotTheIndex() throws {
        let event = ExperimentViewedEvent(
            experiment: Experiment(key: "exp-1", variations: ["a", "b"]),
            result: experimentResult(variationId: 1, key: "treatment"),
            attributes: JSON(["id": "user-1"])
        )

        let props = try properties(of: event)
        XCTAssertEqual(props["variationId"] as? String, "treatment",
                       "Analysis joins on the variation key; the index matches nothing")
        XCTAssertEqual(props["experimentId"] as? String, "exp-1")
    }

    /// A key that looks like an index is the case a weaker fix would still pass.
    func testTheKeyIsSentEvenWhenItLooksLikeAnIndex() throws {
        let event = ExperimentViewedEvent(
            experiment: Experiment(key: "exp-2", variations: ["a", "b"]),
            result: experimentResult(variationId: 1, key: "0"),
            attributes: JSON([:])
        )

        XCTAssertEqual(try properties(of: event)["variationId"] as? String, "0")
    }

    func testExperimentEventCarriesTheHashAttributeAndValue() throws {
        let event = ExperimentViewedEvent(
            experiment: Experiment(key: "exp-3", variations: ["a", "b"]),
            result: experimentResult(hashAttribute: "deviceId", valueHash: "device-9"),
            attributes: JSON([:])
        )

        let props = try properties(of: event)
        XCTAssertEqual(props["hashAttribute"] as? String, "deviceId",
                       "An exposure cannot be attributed without the unit it was assigned on")
        XCTAssertEqual(props["hashValue"] as? String, "device-9")
    }

    // MARK: - Feature Evaluated

    func testFeatureEventCarriesTheVariationKeyWhenAnExperimentDecidedIt() throws {
        let result = FeatureResult(
            value: JSON("b"),
            isOn: true,
            source: "experiment",
            experiment: Experiment(key: "exp-4", variations: ["a", "b"]),
            result: experimentResult(key: "treatment"),
            ruleId: "rule-7"
        )
        let event = FeatureEvaluatedEvent(featureKey: "my-flag", result: result, attributes: JSON([:]))

        let props = try properties(of: event)
        XCTAssertEqual(props["variationId"] as? String, "treatment")
        XCTAssertEqual(props["ruleId"] as? String, "rule-7")
    }

    func testFeatureEventSendsAnEmptyVariationWhenNoExperimentWasInvolved() throws {
        let result = FeatureResult(
            value: JSON("off"),
            isOn: false,
            source: "force",
            experiment: nil,
            result: nil,
            ruleId: "rule-1"
        )
        let event = FeatureEvaluatedEvent(featureKey: "my-flag", result: result, attributes: JSON([:]))

        XCTAssertEqual(try properties(of: event)["variationId"] as? String, "")
    }

    /// `$default` and `""` are what the reference SDK stores. Passing the raw values through means
    /// the same evaluation is recorded differently depending on the platform.
    func testRuleIdIsNormalizedForTheDefaultValue() throws {
        let result = FeatureResult(
            value: JSON("off"),
            isOn: false,
            source: "defaultValue",
            experiment: nil,
            result: nil,
            ruleId: nil
        )
        let event = FeatureEvaluatedEvent(featureKey: "my-flag", result: result, attributes: JSON([:]))

        XCTAssertEqual(try properties(of: event)["ruleId"] as? String, "$default")
    }

    func testRuleIdIsAnEmptyStringRatherThanNullWhenARuleHasNoId() throws {
        let result = FeatureResult(
            value: JSON("on"),
            isOn: true,
            source: "force",
            experiment: nil,
            result: nil,
            ruleId: nil
        )
        let event = FeatureEvaluatedEvent(featureKey: "my-flag", result: result, attributes: JSON([:]))

        XCTAssertEqual(try properties(of: event)["ruleId"] as? String, "")
    }

    // MARK: - Flushing

    /// Records what the SDK asked of it. `GrowthBookPlugin`'s defaults make both calls no-ops, so
    /// the SDK has to dispatch them explicitly for these to be seen.
    private final class RecordingPlugin: GrowthBookPlugin {
        private let lock = NSLock()
        private(set) var flushes = 0
        private(set) var closes = 0

        func flush() { lock.lock(); flushes += 1; lock.unlock() }
        func close() { lock.lock(); closes += 1; lock.unlock() }
    }

    private func makeSDK(with plugin: GrowthBookPlugin) -> GrowthBookSDK {
        GrowthBookBuilder(
            features: "{\"features\":{}}".data(using: .utf8)!,
            attributes: ["id": "user-1"],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .addPlugin(plugin)
        .initializer()
    }

    /// The gap from the report: the tracking plugin batches for up to `batchTimeout` seconds, and
    /// `deinit` does not run when the system kills a suspended app, so nothing delivers the buffer.
    func testFlushReachesPluginsWithoutClosingThem() {
        let plugin = RecordingPlugin()
        let sdk = makeSDK(with: plugin)

        sdk.flush()

        XCTAssertEqual(plugin.flushes, 1, "Backgrounding must be able to deliver the buffer")
        XCTAssertEqual(plugin.closes, 0, "Flushing must not end the plugin — the app may return")
    }

    func testFlushCanBeCalledRepeatedly() {
        let plugin = RecordingPlugin()
        let sdk = makeSDK(with: plugin)

        sdk.flush()
        sdk.flush()

        XCTAssertEqual(plugin.flushes, 2)
        XCTAssertEqual(plugin.closes, 0)
    }

    func testCloseShutsPluginsDown() {
        let plugin = RecordingPlugin()
        let sdk = makeSDK(with: plugin)

        sdk.close()

        XCTAssertEqual(plugin.closes, 1)
    }
}
