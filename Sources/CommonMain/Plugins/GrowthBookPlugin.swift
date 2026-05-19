import Foundation

/// A plugin that receives lifecycle and evaluation events from the GrowthBook SDK.
///
/// Implement this protocol to intercept experiment and feature evaluation events.
/// Plugin methods are always called after the existing tracking callbacks fire.
/// Any errors thrown inside plugin methods must not propagate to callers — the SDK
/// wraps every plugin call so a misbehaving plugin cannot crash the host app.
public protocol GrowthBookPlugin: AnyObject {
    /// Called once when the SDK is initialized.
    func initialize(clientKey: String)

    /// Called every time a user is exposed to an experiment variation.
    /// Mirrors the existing `TrackingCallback` but is routed through the plugin system.
    func onExperimentViewed(experiment: Experiment, result: ExperimentResult)

    /// Called every time a feature flag is evaluated.
    func onFeatureEvaluated(featureKey: String, result: FeatureResult)

    /// Called when the SDK is shut down. Implementations should flush any buffered
    /// data synchronously before returning.
    func close()
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
    public let event: String = "experiment_viewed"
    public let experimentKey: String
    public let variationId: Int
    public let hashAttribute: String?
    public let hashValue: String?

    public init(experiment: Experiment, result: ExperimentResult) {
        self.experimentKey = experiment.key
        self.variationId = result.variationId
        self.hashAttribute = result.hashAttribute
        self.hashValue = result.valueHash
    }
}

public struct FeatureEvaluatedEvent: Encodable {
    public let event: String = "feature_evaluated"
    public let featureKey: String
    public let value: JSON?
    public let source: String
    public let ruleId: String?

    public init(featureKey: String, result: FeatureResult) {
        self.featureKey = featureKey
        self.value = result.value
        self.source = result.source
        self.ruleId = result.ruleId
    }
}

