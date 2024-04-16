import Foundation

/// Defines the GrowthBook context.
@objc public class Context: NSObject {
    /// your api host
    public let apiHost: String?
    /// unique client key
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
            
    public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
    
    public let stickyBucketService: StickyBucketServiceProtocol?
    
    public var stickyBucketIdentifierAttributes: [String]?

    public let remoteEval: Bool
    // Keys are unique identifiers for the features and the values are Feature objects.
    // Feature definitions - To be pulled from API / Cache
    var features: Features

    init(apiHost: String?,
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
         remoteEval: Bool = false) {
        self.apiHost = apiHost
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
        if let apiHost = apiHost, let clientKey = clientKey {
            return "\(apiHost)/sub/\(clientKey)"
        } else {
            return nil
        }
    }
}
