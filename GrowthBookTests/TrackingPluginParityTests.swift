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
        try XCTUnwrap(try encoded(value)["properties_json"] as? [String: Any])
    }

    private func featureEvent(attributes: JSON) -> FeatureEvaluatedEvent {
        FeatureEvaluatedEvent(
            featureKey: "my-flag",
            result: FeatureResult(value: JSON("on"), isOn: true, source: "force",
                                  experiment: nil, result: nil, ruleId: "rule-1"),
            attributes: attributes
        )
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

    // MARK: - Envelope

    /// The ingestor reads the event's own fields from `properties_json`. Under any other key they
    /// arrive as an unread blob, so every event lands with no properties at all.
    func testEventFieldsAreSentUnderPropertiesJson() throws {
        let payload = try encoded(featureEvent(attributes: JSON([:])))

        XCTAssertNotNil(payload["properties_json"] as? [String: Any])
        XCTAssertNil(payload["properties"], "`properties` is not a key the ingestor reads")
    }

    /// These are the columns the events are joined to a user on. Left inside the attributes blob
    /// they parse fine and every identity column comes back empty.
    func testIdentityAttributesArePromotedToTopLevelColumns() throws {
        let payload = try encoded(featureEvent(attributes: JSON([
            "user_id": "u-1",
            "device_id": "d-1",
            "page_id": "p-1",
            "session_id": "s-1"
        ])))

        XCTAssertEqual(payload["user_id"] as? String, "u-1")
        XCTAssertEqual(payload["device_id"] as? String, "d-1")
        XCTAssertEqual(payload["page_id"] as? String, "p-1")
        XCTAssertEqual(payload["session_id"] as? String, "s-1")
    }

    func testDeviceIdFallsBackThroughAnonymousIdThenId() throws {
        let viaAnonymous = try encoded(featureEvent(attributes: JSON(["anonymous_id": "anon-1", "id": "id-1"])))
        XCTAssertEqual(viaAnonymous["device_id"] as? String, "anon-1")

        let viaId = try encoded(featureEvent(attributes: JSON(["id": "id-1"])))
        XCTAssertEqual(viaId["device_id"] as? String, "id-1")
    }

    /// Null and absent are different to the ingestor: an absent key leaves the column unwritten.
    func testIdentityColumnsAreNullRatherThanAbsentWhenUnknown() throws {
        let payload = try encoded(featureEvent(attributes: JSON([:])))

        for key in ["user_id", "device_id", "page_id", "session_id"] {
            XCTAssertTrue(payload[key] is NSNull, "\(key) must be written as null, not omitted")
        }
    }

    /// A non-string identity attribute is not a usable id. Passing it through unchanged would make
    /// the column's type depend on what the host app happened to set.
    func testNonStringIdentityAttributeIsSentAsNull() throws {
        let payload = try encoded(featureEvent(attributes: JSON(["user_id": 42])))

        XCTAssertTrue(payload["user_id"] is NSNull)
    }

    func testRemainingAttributesGoToContextJsonWithoutTheIdentityKeys() throws {
        let payload = try encoded(featureEvent(attributes: JSON([
            "user_id": "u-1",
            "anonymous_id": "anon-1",
            "pageTitle": "Home",
            "country": "UA",
            "plan": "pro"
        ])))

        let context = try XCTUnwrap(payload["context_json"] as? [String: Any])
        XCTAssertEqual(context["country"] as? String, "UA")
        XCTAssertEqual(context["plan"] as? String, "pro")
        XCTAssertNil(context["user_id"], "Promoted keys must not be duplicated into context_json")
        XCTAssertNil(context["anonymous_id"])
        XCTAssertNil(context["pageTitle"])
        XCTAssertNil(payload["attributes"], "`attributes` is not a key the ingestor reads")
    }

    /// The SDK identifiers used to be merged into the attributes the app supplied, which both hid
    /// them from the columns that report them and let an app attribute named `sdk_version`
    /// overwrite the real one.
    func testSdkIdentifiersAreTopLevelAndNotMixedIntoAttributes() throws {
        let payload = try encoded(featureEvent(attributes: JSON(["country": "UA"])))

        XCTAssertEqual(payload["sdk_language"] as? String, "swift")
        XCTAssertEqual(payload["sdk_version"] as? String, gbSdkVersion)
        XCTAssertEqual(payload["url"] as? String, "")

        let context = try XCTUnwrap(payload["context_json"] as? [String: Any])
        XCTAssertNil(context["sdk_language"], "SDK identifiers are columns, not user attributes")
        XCTAssertNil(context["sdk_version"])
    }

    func testCampaignAttributesArePromotedWhenPresent() throws {
        let payload = try encoded(featureEvent(attributes: JSON([
            "utmSource": "newsletter",
            "utmMedium": "email",
            "utmCampaign": "spring",
            "utmTerm": "swift",
            "utmContent": "cta",
            "pageTitle": "Home"
        ])))

        XCTAssertEqual(payload["utm_source"] as? String, "newsletter")
        XCTAssertEqual(payload["utm_medium"] as? String, "email")
        XCTAssertEqual(payload["utm_campaign"] as? String, "spring")
        XCTAssertEqual(payload["utm_term"] as? String, "swift")
        XCTAssertEqual(payload["utm_content"] as? String, "cta")
        XCTAssertEqual(payload["page_title"] as? String, "Home")
    }

    /// Unlike the identity columns, these are omitted rather than nulled when the app never set
    /// them — a null here would read as "this event had no campaign" instead of "not tracked".
    func testCampaignAttributesAreOmittedWhenAbsent() throws {
        let payload = try encoded(featureEvent(attributes: JSON([:])))

        for key in ["utm_source", "utm_medium", "utm_campaign", "utm_term", "utm_content", "page_title"] {
            XCTAssertNil(payload[key], "\(key) must be absent, not null, when untracked")
        }
    }

    /// Both event types share one envelope; the experiment path is the one that carries identity.
    func testExperimentEventUsesTheSameEnvelope() throws {
        let event = ExperimentViewedEvent(
            experiment: Experiment(key: "exp-envelope", variations: ["a", "b"]),
            result: experimentResult(),
            attributes: JSON(["user_id": "u-9", "country": "UA"])
        )
        let payload = try encoded(event)

        XCTAssertEqual(payload["event_name"] as? String, "Experiment Viewed")
        XCTAssertEqual(payload["user_id"] as? String, "u-9")
        XCTAssertNotNil(payload["properties_json"] as? [String: Any])
        let context = try XCTUnwrap(payload["context_json"] as? [String: Any])
        XCTAssertEqual(context["country"] as? String, "UA")
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
