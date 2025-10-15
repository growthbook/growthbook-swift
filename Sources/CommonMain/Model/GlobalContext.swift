import Foundation

@objc public class GlobalContext: NSObject {
    var features: Features
    public var experiments: [Experiment]?
    public var savedGroups: JSON?

    init(
        features: Features = [:],
        experiments: [Experiment]? = nil,
        savedGroups: JSON? = nil
    ) {
        self.features = features
        self.experiments = experiments
        self.savedGroups = savedGroups
    }
}

@objc public class ClientOptions: NSObject {
    /// Switch to globally disable all experiments. Default true.
    public let isEnabled: Bool
    /// If true, random assignment is disabled and only explicitly forced variations are used.
    public let isQaMode: Bool
    /// A function that takes experiment and result as arguments.
    public let trackingClosure: (Experiment, ExperimentResult) -> Void
    /// Sticky bucketing is enabled if stickyBucketService is available
    public let stickyBucketService: StickyBucketServiceProtocol?
    /// Stick bucketing specific configurations for specific keys
    public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
    /// Features that uses sticky bucketing
    public var stickyBucketIdentifierAttributes: [String]?
    
    public var url: String?

    init(isEnabled: Bool,
         stickyBucketAssignmentDocs:  [String: StickyAssignmentsDocument]? = nil,
         stickyBucketIdentifierAttributes: [String]? = nil,
         stickyBucketService: StickyBucketServiceProtocol? = nil,
         isQaMode: Bool,
         url: String? = nil,
         trackingClosure: @escaping (Experiment, ExperimentResult) -> Void) {
        self.isEnabled = isEnabled
        self.stickyBucketAssignmentDocs = stickyBucketAssignmentDocs
        self.stickyBucketIdentifierAttributes = stickyBucketIdentifierAttributes
        self.stickyBucketService = stickyBucketService
        self.isQaMode = isQaMode
        self.trackingClosure = trackingClosure
        self.url = url
    }
}

@objc public class UserContext: NSObject {
    public var attributes: JSON
    public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
    public var forcedVariations: JSON?
    public var forcedFeatureValues: JSON?

    init(attributes: JSON, stickyBucketAssignmentDocs: [String : StickyAssignmentsDocument]? = nil, forcedVariations: JSON? = nil, forcedFeatureValues: JSON? = nil) {
        self.attributes = attributes
        self.stickyBucketAssignmentDocs = stickyBucketAssignmentDocs
        self.forcedVariations = forcedVariations
        self.forcedFeatureValues = forcedFeatureValues
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

@objc public class EvalContext : NSObject {
    public var globalContext: GlobalContext
    public var userContext: UserContext
    public var stackContext: StackContext
    public var options: ClientOptions

    init(globalContext: GlobalContext, userContext: UserContext, stackContext: StackContext, options: ClientOptions) {
        self.globalContext = globalContext
        self.userContext = userContext
        self.stackContext = stackContext
        self.options = options
    }
}
