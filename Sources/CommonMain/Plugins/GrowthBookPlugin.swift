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

    private let eventName = "Experiment Viewed"
    private let properties: Properties
    public let attributes: JSON

    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case properties
        case attributes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(properties, forKey: .properties)
        try container.encode(attributes, forKey: .attributes)
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

    private let eventName = "Feature Evaluated"
    private let properties: Properties
    public let attributes: JSON

    enum CodingKeys: String, CodingKey {
        case eventName = "event_name"
        case properties
        case attributes
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(eventName, forKey: .eventName)
        try container.encode(properties, forKey: .properties)
        try container.encode(attributes, forKey: .attributes)
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

