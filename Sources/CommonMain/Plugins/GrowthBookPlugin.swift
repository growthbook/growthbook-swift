import Foundation

/// A plugin that receives lifecycle and evaluation events from the GrowthBook SDK.
///
/// Implement this protocol to intercept experiment and feature evaluation events.
/// Plugin methods are always called after the existing tracking callbacks fire.
public protocol GrowthBookPlugin: AnyObject {
    /// Called once when the SDK is initialized.
    func initialize(clientKey: String)

    /// Called every time a user is exposed to an experiment variation.
    /// Mirrors the existing `TrackingCallback` but is routed through the plugin system.
    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?)

    /// Called every time a feature flag is evaluated.
    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?)

    /// Sends any buffered data without shutting down, and blocks until it has left.
    ///
    /// Separate from `close` because an app heading to the background needs its buffer delivered
    /// but expects to keep recording when it returns; `close` ends the plugin for good.
    func flush()

    /// Called when the SDK is shut down. Implementations should flush any buffered
    /// data synchronously before returning.
    func close()
}

public extension GrowthBookPlugin {
    func initialize(clientKey: String) {}
    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {}
    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {}
    func flush() {}
    func close() {}
}

// MARK: - Ingest event models

/// Wire format for a single event sent to the GrowthBook ingest endpoint.
public enum IngestEvent: Encodable {
    case experimentViewed(ExperimentViewedEvent)
    case featureEvaluated(FeatureEvaluatedEvent)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case .experimentViewed(let event): try event.encode(to: encoder)
        case .featureEvaluated(let event): try event.encode(to: encoder)
        }
    }
}

/// The envelope every ingested event is wrapped in.
///
/// The ingestor reads a flat payload: the event's own fields go in `properties_json`, the unit's
/// identity is promoted to top-level columns, and whatever attributes are left land in
/// `context_json`. Sending the attributes as one undivided blob parses, but the identity columns
/// come back empty, so the events cannot be joined to a user at all.
///
/// `url` is always empty on Apple platforms: the plugin callbacks carry attributes but no URL, and
/// widening the `GrowthBookPlugin` protocol to pass one would break every app that implements it.
/// The Kotlin SDK sends an empty string here for the same reason.
struct IngestEnvelope<Properties: Encodable>: Encodable {
    let eventName: String
    let properties: Properties
    let attributes: JSON

    /// Attribute keys promoted to top-level fields; everything else goes to `context_json`.
    /// Mirrors the reference SDK's list exactly — dropping a key here silently stops it being
    /// queryable as a column on the ingested event.
    static var topLevelAttributeKeys: Set<String> {
        [
            "user_id", "device_id", "anonymous_id", "id", "page_id", "session_id",
            "utmCampaign", "utmContent", "utmMedium", "utmSource", "utmTerm", "pageTitle"
        ]
    }

    private enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case propertiesJson = "properties_json"
        case sdkLanguage = "sdk_language"
        case sdkVersion = "sdk_version"
        case url
        case contextJson = "context_json"
        case userId = "user_id"
        case deviceId = "device_id"
        case pageId = "page_id"
        case sessionId = "session_id"
        case utmSource = "utm_source"
        case utmMedium = "utm_medium"
        case utmCampaign = "utm_campaign"
        case utmTerm = "utm_term"
        case utmContent = "utm_content"
        case pageTitle = "page_title"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(eventName, forKey: .eventName)
        try container.encode(properties, forKey: .propertiesJson)
        try container.encode("swift", forKey: .sdkLanguage)
        try container.encode(gbSdkVersion, forKey: .sdkVersion)
        try container.encode("", forKey: .url)

        let values = attributes.dictionaryObject ?? [:]
        let context = values.filter { !Self.topLevelAttributeKeys.contains($0.key) }
        try container.encode(JSON(context), forKey: .contextJson)

        // Identity columns are always written, null when the attribute is missing or is not a
        // string. Omitting them instead would leave the column absent rather than explicitly empty.
        func string(_ key: String) -> String? { values[key] as? String }

        try encode(string("user_id"), orNullFor: .userId, in: &container)
        try encode(string("device_id") ?? string("anonymous_id") ?? string("id"),
                   orNullFor: .deviceId, in: &container)
        try encode(string("page_id"), orNullFor: .pageId, in: &container)
        try encode(string("session_id"), orNullFor: .sessionId, in: &container)

        // Campaign fields are optional: absent means absent, not null.
        try container.encodeIfPresent(string("utmSource"), forKey: .utmSource)
        try container.encodeIfPresent(string("utmMedium"), forKey: .utmMedium)
        try container.encodeIfPresent(string("utmCampaign"), forKey: .utmCampaign)
        try container.encodeIfPresent(string("utmTerm"), forKey: .utmTerm)
        try container.encodeIfPresent(string("utmContent"), forKey: .utmContent)
        try container.encodeIfPresent(string("pageTitle"), forKey: .pageTitle)
    }

    private func encode(
        _ value: String?,
        orNullFor key: CodingKeys,
        in container: inout KeyedEncodingContainer<CodingKeys>
    ) throws {
        if let value = value {
            try container.encode(value, forKey: key)
        } else {
            try container.encodeNil(forKey: key)
        }
    }
}

public struct ExperimentViewedEvent: Encodable {
    private struct Properties: Encodable {
        let experimentId: String
        /// The assigned variation's key, not its index.
        ///
        /// Analysis joins exposures on the key, so sending the array index means an experiment with
        /// custom variation keys gets no matched exposures at all — the events arrive and simply
        /// never line up. The JS, Go and Kotlin SDKs all send the key.
        let variationId: String
        /// The attribute the assignment was made on, and its value. Without them an exposure cannot
        /// be attributed to the unit it belongs to.
        let hashAttribute: String?
        let hashValue: String?
    }

    /// The name the ingestor matches on. Kept in one place so the dedupe key and the wire payload
    /// cannot drift apart.
    static let eventName = "Experiment Viewed"

    private let properties: Properties
    public let attributes: JSON

    public func encode(to encoder: Encoder) throws {
        try IngestEnvelope(eventName: Self.eventName, properties: properties, attributes: attributes)
            .encode(to: encoder)
    }

    public init(experiment: Experiment, result: ExperimentResult, attributes: JSON) {
        self.properties = Properties(
            experimentId: experiment.key,
            variationId: result.key,
            hashAttribute: result.hashAttribute,
            hashValue: result.valueHash
        )
        self.attributes = attributes
    }
}

public struct FeatureEvaluatedEvent: Encodable {
    private struct Properties: Encodable {
        let feature: String
        let value: JSON?
        let source: String
        /// Normalized the way the reference SDK does it: `$default` when the value came from the
        /// feature's default, and an empty string rather than null when a rule carries no id. Left
        /// as-is, the same evaluation produces a different stored value on each platform.
        let ruleId: String
        /// The variation key when the value came from an experiment, empty otherwise.
        let variationId: String
    }

    /// See `ExperimentViewedEvent.eventName`.
    static let eventName = "Feature Evaluated"

    private let properties: Properties
    public let attributes: JSON

    public func encode(to encoder: Encoder) throws {
        try IngestEnvelope(eventName: Self.eventName, properties: properties, attributes: attributes)
            .encode(to: encoder)
    }

    public init(featureKey: String, result: FeatureResult, attributes: JSON) {
        self.properties = Properties(
            feature: featureKey,
            value: result.value,
            source: result.source,
            ruleId: result.source == "defaultValue" ? "$default" : (result.ruleId ?? ""),
            variationId: result.experimentResult?.key ?? ""
        )
        self.attributes = attributes
    }
}

