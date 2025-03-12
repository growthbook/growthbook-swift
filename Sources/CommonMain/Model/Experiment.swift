import Foundation

/// Defines a single experiment
@objc public final class Experiment: NSObject, Codable, Sendable {
    /// The globally unique tracking key for the experiment
    public let key: String
    /// The different variations to choose between
    public let variations: [JSON]
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
    public let namespace: [JSON]?
    /// Each item defines a prerequisite where a `condition` must evaluate against a parent feature's value (identified by `id`). If `gate` is true, then this is a blocking feature-level prerequisite; otherwise it applies to the current rule only.
    public let parentConditions: [ParentConditionInterface]?    
    /// All users included in the experiment will be forced into the specific variation index
    public let hashAttribute: String?
    /// When using sticky bucketing, can be used as a fallback to assign variations
    public let fallbackAttribute: String?
    /// The hash version to use (default to `1`)
    public let hashVersion: Float?
    /// If true, sticky bucketing will be disabled for this experiment. (Note: sticky bucketing is only available if a StickyBucketingService is provided in the Context)
    public let disableStickyBucketing: Bool?
    /// An sticky bucket version number that can be used to force a re-bucketing of users (default to `0`)
    public let bucketVersion: Int?
    /// Any users with a sticky bucket version less than this will be excluded from the experiment
    public let minBucketVersion: Int?
    /// How to weight traffic between variations. Must add to 1.
    public let weights: [Float]?
    /// If set to false, always return the control (first variation)
    public let isActive: Bool?
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    public let coverage: Float?
    /// Optional targeting condition
    public let condition: JSON?
    /// All users included in the experiment will be forced into the specific variation index
    public let force: Int?
    /// Array of ranges, one per variation
    public let ranges: [BucketRange]?
    /// Meta info about the variations
    public let meta: [VariationMeta]?
    /// Array of filters to apply
    public let filters: [Filter]?
    /// The hash seed to use
    public let seed: String?
    /// Human-readable name for the experiment
    public let name: String?
    /// Id of the current experiment phase
    public let phase: String?
    
    public init(key: String,
                variations: [Any] = [],
                namespace: [Any]? = nil,
                parentConditions: [ParentConditionInterface]? = nil,
                hashAttribute: String? = nil,
                fallBackAttribute: String? = nil,
                hashVersion: Float? = nil,
                disableStickyBucketing: Bool? = nil,
                bucketVersion: Int? = nil,
                minBucketVersion: Int? = nil,
                weights: [Float]? = nil,
                isActive: Bool = true,
                coverage: Float? = nil,
                condition: Any? = nil,
                force: Int? = nil,
                ranges: [BucketRange]? = nil,
                meta: [VariationMeta]? = nil,
                filters: [Filter]? = nil,
                seed: String? = nil,
                name: String? = nil,
                phase: String? = nil) {
        self.key = key
        self.variations = JSON(variations).arrayValue
        if let namespace = namespace {
            self.namespace = JSON(namespace).arrayValue
        } else {
            self.namespace = nil
        }
        self.parentConditions = parentConditions
        self.hashAttribute = hashAttribute
        self.fallbackAttribute = fallBackAttribute
        self.hashVersion = hashVersion
        self.disableStickyBucketing = disableStickyBucketing
        self.bucketVersion = bucketVersion
        self.minBucketVersion = minBucketVersion
        self.weights = weights
        self.isActive = isActive
        self.coverage = coverage
        if let condition = condition {
            self.condition = JSON(condition)
        } else {
            self.condition = nil
        }
        self.force = force
        self.ranges = ranges
        self.meta = meta
        self.filters = filters
        self.seed = seed
        self.name = name
        self.phase = phase
    }

    init(key: String,
         variations: [JSON] = [],
         namespace: [JSON]? = nil,
         parentConditions: [ParentConditionInterface]? = nil,
         hashAttribute: String? = nil,
         fallBackAttribute: String? = nil,
         hashVersion: Float? = nil,
         disableStickyBucketing: Bool? = nil,
         bucketVersion: Int? = nil,
         minBucketVersion: Int? = nil,
         weights: [Float]? = nil,
         isActive: Bool = true,
         coverage: Float? = nil,
         condition: Condition? = nil,
         force: Int? = nil,
         ranges: [BucketRange]? = nil,
         meta: [VariationMeta]? = nil,
         filters: [Filter]? = nil,
         seed: String? = nil,
         name: String? = nil,
         phase: String? = nil) {
        self.key = key
        self.variations = variations
        self.namespace = namespace
        self.parentConditions = parentConditions
        self.hashAttribute = hashAttribute
        self.fallbackAttribute = fallBackAttribute
        self.hashVersion = hashVersion
        self.disableStickyBucketing = disableStickyBucketing
        self.bucketVersion = bucketVersion
        self.minBucketVersion = minBucketVersion
        self.weights = weights
        self.isActive = isActive
        self.coverage = coverage
        self.condition = condition
        self.force = force
        self.ranges = ranges
        self.meta = meta
        self.filters = filters
        self.seed = seed
        self.name = name
        self.phase = phase
    }

    init(json: [String: JSON]) {
        key = json["key"]?.stringValue ?? ""

        variations = json["variations"]?.arrayValue ?? []

        namespace = json["namespace"]?.arrayValue
        
        parentConditions = json["parentConditions"]?.map({ key, value in
            ParentConditionInterface(json: value.dictionaryValue)
        })
        
        hashAttribute = json["hashAttribute"]?.stringValue
        
        fallbackAttribute = json["fallbackAttribute"]?.stringValue
        
        hashVersion = json["hashVersion"]?.floatValue
        
        disableStickyBucketing = json["disableStickyBucketing"]?.boolValue
        
        bucketVersion = json["bucketVersion"]?.intValue
        
        minBucketVersion = json["minBucketVersion"]?.intValue

        isActive = json["active"]?.boolValue ?? true

        if let weights = json["weights"] {
            self.weights = JSON.convertToArrayFloat(jsonArray: weights.arrayValue)
        } else {
            self.weights = nil
        }

        coverage = json["coverage"]?.floatValue

        condition = json["condition"]

        force = json["force"]?.intValue
        
        if json["filters"] != nil { }
        
        ranges = json["ranges"]?.map({ key, value in
            BucketRange(json: value)
        })
        
        meta = json["meta"]?.map({ key, value in
            VariationMeta(json: value.dictionaryValue)
        })
                
        filters = json["filters"]?.map({ key, value in
            Filter(json: value.dictionaryValue)
        })
        
        seed = json["seed"]?.stringValue
        
        name = json["name"]?.stringValue
        
        phase = json["phase"]?.stringValue
        
    }
}

/// The result of running an Experiment given a specific Context
@objc public final class ExperimentResult: NSObject, Codable, Sendable {
    /// Whether or not the user is part of the experiment
    public let inExperiment: Bool
    /// The array index of the assigned variation
    public let variationId: Int
    /// The array value of the assigned variation
    public let value: JSON
    /// The user attribute used to assign a variation
    public let hashAttribute: String?
    /// The value of that attribute
    public let valueHash: String?
    /// The unique key for the assigned variation
    public let key: String
    /// The human-readable name of the assigned variation
    public let name: String?
    /// The hash value used to assign a variation (float from `0` to `1`)
    public let bucket: Float?
    /// Used for holdout groups
    public let passthrough: Bool?
    /// If a hash was used to assign a variation
    public let hashUsed: Bool?
    /// The id of the feature (if any) that the experiment came from
    public let featureId: String?
    /// If sticky bucketing was used to assign a variation
    public let stickyBucketUsed: Bool?

    init(inExperiment: Bool,
         variationId: Int,
         value: JSON,
         hashAttribute: String? = nil,
         hashValue: String? = nil,
         key: String,
         name: String? = nil,
         bucket: Float? = nil,
         passthrough: Bool? = nil,
         hashUsed: Bool? = nil,
         featureId: String? = nil,
         stickyBucketUsed: Bool? = nil) {
        self.inExperiment = inExperiment
        self.variationId = variationId
        self.value = value
        self.hashAttribute = hashAttribute
        self.valueHash = hashValue
        self.key = key
        self.name = name
        self.bucket = bucket
        self.passthrough = passthrough
        self.hashUsed = hashUsed
        self.featureId = featureId
        self.stickyBucketUsed = stickyBucketUsed
    }
    
    init(json: [String: JSON]) {
        inExperiment = json["inExperiment"]?.boolValue ?? false
        variationId = json["variationId"]?.intValue ?? 0
        value = json["value"] ?? JSON()
        hashAttribute = json["hashAttribute"]?.stringValue
        valueHash = json["valueHash"]?.stringValue
        key = json["key"]?.stringValue ?? ""
        name = json["name"]?.stringValue
        bucket = json["bucket"]?.floatValue
        passthrough = json["passthrough"]?.boolValue
        hashUsed = json["hashUsed"]?.boolValue
        featureId = json["featureId"]?.stringValue
        stickyBucketUsed = json["stickyBucketUsed"]?.boolValue
    }
}
