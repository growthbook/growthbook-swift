import Foundation

/// Defines the GrowthBook context.
@objc public class Context: NSObject {
    /// Registered API Key for GrowthBook SDK
    public let apiKey: String?
    /// Host URL for GrowthBook
    public let hostURL: String?
    /// Switch to globally disable all experiments. Default true.
    public let isEnabled: Bool
    /// Map of user attributes that are used to assign variations
    public var attributes: JSON
    /// Force specific experiments to always assign a specific variation (used for QA)
    public let forcedVariations: JSON?
    /// If true, random assignment is disabled and only explicitly forced variations are used.
    public let isQaMode: Bool
    /// A function that takes experiment and result as arguments.
    public let trackingClosure: (Experiment, ExperimentResult) -> Void

    // Keys are unique identifiers for the features and the values are Feature objects.
    // Feature definitions - To be pulled from API / Cache
    var features: Features

    init(apiKey: String?,
         hostURL: String?,
         isEnabled: Bool,
         attributes: JSON,
         forcedVariations: JSON?,
         isQaMode: Bool,
         trackingClosure: @escaping (Experiment, ExperimentResult) -> Void,
         features: Features = [:]) {
        self.apiKey = apiKey
        self.hostURL = hostURL
        self.isEnabled = isEnabled
        self.attributes = attributes
        self.forcedVariations = forcedVariations
        self.isQaMode = isQaMode
        self.trackingClosure = trackingClosure
        self.features = features
    }
}
