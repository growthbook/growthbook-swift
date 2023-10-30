import Foundation

/// Defines a single experiment
@objc public class Experiment: NSObject, Codable {
    /// The globally unique tracking key for the experiment
    public let key: String
    /// The different variations to choose between
    public let variations: [JSON]
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
    public let namespace: [JSON]?
    /// All users included in the experiment will be forced into the specific variation index
    public let hashAttribute: String?
    /// How to weight traffic between variations. Must add to 1.
    public var weights: [Float]?
    /// If set to false, always return the control (first variation)
    public var isActive: Bool
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    public var coverage: Float?
    /// Optional targeting condition
    public var condition: JSON?
    /// All users included in the experiment will be forced into the specific variation index
    public var force: Int?
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
                hashAttribute: String? = nil,
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
        self.hashAttribute = hashAttribute
        self.weights = weights
        self.isActive = isActive
        self.coverage = coverage
        if let condition = condition {
            self.condition = JSON(condition)
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
         hashAttribute: String? = nil,
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
        self.hashAttribute = hashAttribute
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

        hashAttribute = json["hashAttribute"]?.stringValue

        isActive = json["active"]?.boolValue ?? true

        if let weights = json["weights"] {
            self.weights = JSON.convertToArrayFloat(jsonArray: weights.arrayValue)
        }

        coverage = json["coverage"]?.floatValue

        condition = json["condition"]

        force = json["force"]?.intValue
        
        ranges = json["ranges"]?.arrayObject as? [BucketRange]
        
        meta = json["meta"]?.arrayObject as? [VariationMeta]
        
        filters = json["filters"]?.arrayObject as? [Filter]
        
        seed = json["seed"]?.stringValue
        
        name = json["name"]?.stringValue
        
        phase = json["phase"]?.stringValue
        
    }
}

/// The result of running an Experiment given a specific Context
@objc public class ExperimentResult: NSObject, Codable {
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

    init(inExperiment: Bool,
         variationId: Int,
         value: JSON,
         hashAttribute: String? = nil,
         hashValue: String? = nil,
         key: String,
         name: String? = nil,
         bucket: Float? = nil,
         passthrough: Bool? = nil) {
        self.inExperiment = inExperiment
        self.variationId = variationId
        self.value = value
        self.hashAttribute = hashAttribute
        self.valueHash = hashValue
        self.key = key
        self.name = name
        self.bucket = bucket
        self.passthrough = passthrough
    }
}
