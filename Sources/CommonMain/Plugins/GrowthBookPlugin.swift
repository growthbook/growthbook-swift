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

    /// Called when the SDK is shut down. Implementations should flush any buffered
    /// data synchronously before returning.
    func close()
}

public extension GrowthBookPlugin {
    func initialize(clientKey: String) {}
    func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {}
    func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {}
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
        let variationId: Int
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
        self.properties = Properties(experimentId: experiment.key, variationId: result.variationId)
        self.attributes = attributes
    }
}

public struct FeatureEvaluatedEvent: Encodable {
    private struct Properties: Encodable {
        let feature: String
        let value: JSON?
        let source: String
        let ruleId: String?
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
        self.properties = Properties(feature: featureKey, value: result.value, source: result.source, ruleId: result.ruleId)
        self.attributes = attributes
    }
}

