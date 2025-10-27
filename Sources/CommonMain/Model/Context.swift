import Foundation

/// Defines the GrowthBook context.
@objc public class Context: NSObject {
    /// Your api host
    public let apiHost: String?
    /// Your streaming host
    public var streamingHost: String?
    /// Unique client key
    public let clientKey: String?
    /// Encryption key for encrypted features.
    public let encryptionKey: String?
    /// Switch to globally disable all experiments. Default true.
    public let isEnabled: Bool
    /// Map of user attributes that are used to assign variations
    public var attributes: JSON
    /// Force specific experiments to always assign a specific variation (used for QA)
    public var forcedVariations: JSON?
    /// If true, random assignment is disabled and only explicitly forced variations are used.
    public let isQaMode: Bool
    /// A function that takes experiment and result as arguments.
    public let trackingClosure: (Experiment, ExperimentResult) -> Void
    /// Disable background streaming connection
    public let backgroundSync: Bool
    /// Sticky bucketing is enabled if stickyBucketService is available
    public let stickyBucketService: StickyBucketServiceProtocol?
    /// Stick bucketing specific configurations for specific keys
    public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
    /// Features that uses sticky bucketing
    public var stickyBucketIdentifierAttributes: [String]?
    /// Enable to use remote evaluation
    public let remoteEval: Bool
    /// Keys are unique identifiers for the features and the values are Feature objects.
    /// Feature definitions - To be pulled from API / Cache
    var features: Features
    /// Target the same group of users across multiple features and experiments with Saved Groups
    public var savedGroups: JSON?
    
    public var url: String? = nil
    
    public var forcedFeatureValues: JSON? = nil

    init(apiHost: String?,
         streamingHost: String?,
         clientKey: String?,
         encryptionKey: String?,
         isEnabled: Bool,
         attributes: JSON,
         forcedVariations: JSON?,
         stickyBucketAssignmentDocs:  [String: StickyAssignmentsDocument]? = nil,
         stickyBucketIdentifierAttributes: [String]? = nil,
         stickyBucketService: StickyBucketServiceProtocol? = nil,
         isQaMode: Bool,
         trackingClosure: @escaping (Experiment, ExperimentResult) -> Void,
         features: Features = [:],
         backgroundSync: Bool = false,
         remoteEval: Bool = false,
         savedGroups: JSON? = nil,
         url: String? = nil,
         forcedFeatureValues: JSON? = nil) {
        self.apiHost = apiHost
        self.streamingHost = streamingHost
        self.clientKey = clientKey
        self.encryptionKey = encryptionKey
        self.isEnabled = isEnabled
        self.attributes = attributes
        self.forcedVariations = forcedVariations
        self.stickyBucketAssignmentDocs = stickyBucketAssignmentDocs
        self.stickyBucketIdentifierAttributes = stickyBucketIdentifierAttributes
        self.stickyBucketService = stickyBucketService
        self.isQaMode = isQaMode
        self.trackingClosure = trackingClosure
        self.features = features
        self.backgroundSync = backgroundSync
        self.remoteEval = remoteEval
        self.savedGroups = savedGroups
        self.url = url
        self.forcedFeatureValues = forcedFeatureValues
    }
    
    @objc public func getFeaturesURL() -> String? {
        if let apiHost = apiHost, let clientKey = clientKey {
            return "\(apiHost)/api/features/\(clientKey)"
        } else {
            return nil
        }
    }
    
    @objc public func getRemoteEvalUrl() -> String? {
        if let apiHost = apiHost, let clientKey = clientKey {
            return  "\(apiHost)/api/eval/\(clientKey)"
        } else {
            return nil
        }
    }
    
    @objc public func getSSEUrl() -> String? {
        if let host = streamingHost ?? apiHost, let clientKey = clientKey {
            return "\(host)/sub/\(clientKey)"
        } else {
            return nil
        }
    }
}
