import Foundation

@objc public class GlobalContext: NSObject {
    let features: Features
    public let experiments: [Experiment]?
    public let savedGroups: JSON?

    init(
        features: Features,
        experiments: [Experiment]?,
        savedGroups: JSON?
    ) {
        self.features = features
        self.experiments = experiments
        self.savedGroups = savedGroups
    }
}

@objc public class MultiUserOptions: NSObject {
//    /// your api host
//    public let apiHost: String?
//    /// unique client key
//    public let clientKey: String?
//    /// Encryption key for encrypted features.
//    public let encryptionKey: String?
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
//    /// Enable to use remote evaluation
//    public let remoteEval: Bool
    // Keys are unique identifiers for the features and the values are Feature objects.
    // Feature definitions - To be pulled from API / Cache
    var features: Features

    public var savedGroups: JSON?

    init(
//        apiHost: String?,
//         clientKey: String?,
//         encryptionKey: String?,
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
//         remoteEval: Bool = false,
         savedGroups: JSON? = nil) {
//        self.apiHost = apiHost
//        self.clientKey = clientKey
//        self.encryptionKey = encryptionKey
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
//        self.remoteEval = remoteEval
        self.savedGroups = savedGroups
    }

//    @objc public func getFeaturesURL() -> String? {
//        if let apiHost = apiHost, let clientKey = clientKey {
//            return "\(apiHost)/api/features/\(clientKey)"
//        } else {
//            return nil
//        }
//    }
//
//    @objc public func getRemoteEvalUrl() -> String? {
//        if let apiHost = apiHost, let clientKey = clientKey {
//            return  "\(apiHost)/api/eval/\(clientKey)"
//        } else {
//            return nil
//        }
//    }
//
//    @objc public func getSSEUrl() -> String? {
//        if let apiHost = apiHost, let clientKey = clientKey {
//            return "\(apiHost)/sub/\(clientKey)"
//        } else {
//            return nil
//        }
//    }
}

@objc public class UserContext: NSObject {
    public let attributes: JSON
    public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
    public let forcedVariations: JSON?
    public let forcedFeatureValues: JSON?

    init(
        attributes: JSON,
        stickyBucketAssignmentDocs: [String : StickyAssignmentsDocument]?,
        forcedVariations: JSON?,
        forcedFeatureValues: JSON?
    )
    {
        self.attributes = attributes
        self.stickyBucketAssignmentDocs = stickyBucketAssignmentDocs
        self.forcedVariations = forcedVariations
        self.forcedFeatureValues = forcedFeatureValues
    }

    public override var description: String {
        return """
        UserContext(
          attributes: \(attributes),
          stickyBucketAssignmentDocs: \(String(describing: stickyBucketAssignmentDocs)),
          forcedVariations: \(String(describing: forcedVariations)),
          forcedFeatureValues: \(String(describing: forcedFeatureValues))
        )
        """
    }
}

@objc public class StackContext: NSObject {
    public var id: String?
    public var evaluatedFeatures: Set<String>

    init(id: String? = nil, evaluatedFeatures: Set<String> = []) {
        self.id = id
        self.evaluatedFeatures = evaluatedFeatures
    }
}

public struct EvalContext {
    public let globalContext: GlobalContext
    public let userContext: UserContext
    public let stackContext: StackContext
    public let options: MultiUserOptions

    init(globalContext: GlobalContext, userContext: UserContext, stackContext: StackContext, options: MultiUserOptions) {
        self.globalContext = globalContext
        self.userContext = userContext
        self.stackContext = stackContext
        self.options = options
    }
}
