import Foundation

/// A Feature object consists of possible values plus rules for how to assign values to users.
@objc public class Feature: NSObject, Codable {
    /// The default value (should use null if not specified)
    public let defaultValue: JSON?
    /// Array of Rule objects that determine when and how the defaultValue gets overridden
    public let rules: [FeatureRule]?

    init(defaultValue: JSON? = nil, rules: [FeatureRule]? = nil) {
        self.defaultValue = defaultValue
        self.rules = rules
    }
}

/// Rule object consists of various definitions to apply to calculate feature value
public struct FeatureRule: Codable {
    /// Optional targeting condition
    public let condition: JSON?
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    public let coverage: Float?
    /// Immediately force a specific value (ignore every other option besides condition and coverage)
    public let force: JSON?
    /// Run an experiment (A/B test) and randomly choose between these variations
    public let variations: [JSON]?
    /// The globally unique tracking key for the experiment (default to the feature key)
    public let key: String?
    /// How to weight traffic between variations. Must add to 1.
    public let weights: [Float]?
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment.
    public let namespace: [JSON]?
    /// What user attribute should be used to assign variations (defaults to id)
    public let hashAttribute: String?

    init(condition: Condition? = nil,
         coverage: Float? = nil,
         force: JSON? = nil,
         variations: [JSON]? = nil,
         key: String? = nil,
         weights: [Float]? = nil,
         namespace: [JSON]? = nil,
         hashAttribute: String? = nil) {
        self.condition = condition
        self.coverage = coverage
        self.force = force
        self.variations = variations
        self.key = key
        self.weights = weights
        self.namespace = namespace
        self.hashAttribute = hashAttribute
    }
}

/// Enum For defining feature value source
enum FeatureSource: String {
    /// Queried Feature doesn't exist in GrowthBook
    case unknownFeature
    /// Default Value for the Feature is being processed
    case defaultValue
    /// Forced Value for the Feature is being processed
    case force
    /// Experiment Value for the Feature is being processed
    case experiment
}

 /// Result for Feature
@objc public class FeatureResult: NSObject, Decodable {
    /// The assigned value of the feature
    public let value: JSON?
    /// The assigned value cast to a boolean
    public let isOn: Bool
    /// The assigned value cast to a boolean and then negated
    public let isOff: Bool
    /// One of "unknownFeature", "defaultValue", "force", or "experiment"
    public let source: String
    /// When source is "experiment", this will be the Experiment object used
    public let experiment: Experiment?
    /// When source is "experiment", this will be an ExperimentResult object
    public let experimentResult: ExperimentResult?

    init(value: JSON? = JSON.null, isOn: Bool = false, source: String, experiment: Experiment? = nil, result: ExperimentResult? = nil) {
        self.isOn = isOn
        self.isOff = !isOn
        self.value = value
        self.source = source
        self.experiment = experiment
        self.experimentResult = result
    }
}
