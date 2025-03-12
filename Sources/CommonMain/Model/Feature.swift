import Foundation

/// A Feature object consists of possible values plus rules for how to assign values to users.
@objc public final class Feature: NSObject, Codable, Sendable {
    /// The default value (should use null if not specified)
    public let defaultValue: JSON?
    /// Array of Rule objects that determine when and how the defaultValue gets overridden
    public let rules: [FeatureRule]?

    init(defaultValue: JSON? = nil, rules: [FeatureRule]? = nil) {
        self.defaultValue = defaultValue
        self.rules = rules
    }
    
    init(json: [String: JSON]) {
        defaultValue = json["defaultValue"]
        
        rules = json["rules"]?.map({ key, value in
            FeatureRule(json: value.dictionaryValue)
        })
    }
}

/// Rule object consists of various definitions to apply to calculate feature value
public struct FeatureRule: Codable, Sendable {
    /// Unique feature rule id
    public let id: String?
    /// Optional targeting condition
    public let condition: JSON?
    /// Each item defines a prerequisite where a `condition` must evaluate against a parent feature's value (identified by `id`). If `gate` is true, then this is a blocking feature-level prerequisite; otherwise it applies to the current rule only.
    public let parentConditions: [ParentConditionInterface]?
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
    /// Hash version of hash function
    public let hashVersion: Float?
    /// When using sticky bucketing, can be used as a fallback to assign variations
    public let fallbackAttribute: String?
    /// If true, sticky bucketing will be disabled for this experiment. (Note: sticky bucketing is only available if a StickyBucketingService is provided in the Context)
    public let disableStickyBucketing: Bool?
    /// An sticky bucket version number that can be used to force a re-bucketing of users (default to `0`)
    public let bucketVersion: Int?
    /// Any users with a sticky bucket version less than this will be excluded from the experiment
    public let minBucketVersion: Int?
    /// A more precise version of `coverage`
    public let range: BucketRange?
    /// Ranges for experiment variations
    public let ranges: [BucketRange]?
    /// Meta info about the experiment variations
    public let meta: [VariationMeta]?
    /// Array of filters to apply to the rule
    public let filters: [Filter]?
    /// Seed to use for hashing
    public let seed: String?
    /// Human-readable name for the experiment
    public let name: String?
    /// The phase id of the experiment
    public let phase: String?
    /// Array of tracking calls to fire
    public let tracks: [Track]?

    init(id: String? = nil, condition: Condition? = nil,
         coverage: Float? = nil,
         parentConditions: [ParentConditionInterface]? = nil,
         force: JSON? = nil,
         variations: [JSON]? = nil,
         key: String? = nil,
         weights: [Float]? = nil,
         namespace: [JSON]? = nil,
         hashAttribute: String? = nil,
         fallBackAttribute: String? = nil,
         disableStickyBucketing: Bool? = nil,
         bucketVersion: Int? = nil,
         minBucketVersion: Int? = nil,
         hashVersion: Float? = nil,
         range: BucketRange? = nil,
         ranges: [BucketRange]? = nil,
         meta: [VariationMeta]? = nil,
         filters: [Filter]? = nil,
         seed: String? = nil,
         name: String? = nil,
         phase: String? = nil,
         tracks: [Track]? = nil) {
        self.id = id
        self.condition = condition
        self.coverage = coverage
        self.parentConditions = parentConditions
        self.force = force
        self.variations = variations
        self.key = key
        self.weights = weights
        self.namespace = namespace
        self.hashAttribute = hashAttribute
        self.fallbackAttribute = fallBackAttribute
        self.disableStickyBucketing = disableStickyBucketing
        self.bucketVersion = bucketVersion
        self.minBucketVersion = minBucketVersion
        self.hashVersion = hashVersion
        self.range = range
        self.ranges = ranges
        self.meta = meta
        self.filters = filters
        self.seed = seed
        self.name = name
        self.phase = phase
        self.tracks = tracks
    }
    
    init(json: [String: JSON]) {        
        id = json["id"]?.stringValue
        
        condition = json["condition"]

        parentConditions = json["parentConditions"]?.map({ key, value in
            ParentConditionInterface(json: value.dictionaryValue)
        })
        
        coverage = json["coverage"]?.floatValue
        
        force = json["force"]
        
        variations = json["variations"]?.arrayValue
        
        key = json["key"]?.stringValue
 
        if let weights = json["weights"]?.arrayValue {
            self.weights = JSON.convertToArrayFloat(jsonArray: weights)
        } else {
            self.weights = nil
        }
        
        namespace = json["namespace"]?.arrayValue
        
        hashAttribute = json["hashAttribute"]?.stringValue
        
        hashVersion = json["hashVersion"]?.floatValue

        fallbackAttribute = json["fallbackAttribute"]?.stringValue
        
        disableStickyBucketing = json["disableStickyBucketing"]?.boolValue
        
        bucketVersion = json["bucketVersion"]?.intValue
        
        minBucketVersion = json["minBucketVersion"]?.intValue
        
        if let range = json["range"] {
            self.range = BucketRange(json: range)
        } else {
            self.range = nil
        }
        
        if let ranges = json["ranges"] {
            self.ranges = ranges.map({ key, value in
                BucketRange(json: value)
            })
        } else {
            self.ranges = nil
        }
        
        meta = json["meta"]?.map({ key, value in
            VariationMeta(json: value.dictionaryValue)
        })
                
        filters = json["filters"]?.map({ key, value in
            Filter(json: value.dictionaryValue)
        })
    
        seed = json["seed"]?.stringValue
        
        name = json["name"]?.stringValue
        
        phase = json["phase"]?.stringValue
        
        tracks = json["tracks"]?.map({ key, value in
            Track(json: value.dictionaryValue)
        })
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
    /// CyclicPrerequisite Value for the Feature is being processed
    case cyclicPrerequisite
    /// Prerequisite Value for the Feature is being processed
    case prerequisite
    /// Override Value for the Feature is being processed
    case override
}

 /// Result for Feature
@objc public final class FeatureResult: NSObject, Codable, Sendable {
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
    /// Unique identifier of rule
    public let ruleId: String?

    init(value: JSON? = JSON.null, isOn: Bool = false, source: String, experiment: Experiment? = nil, result: ExperimentResult? = nil, ruleId: String? = nil) {
        self.isOn = isOn
        self.isOff = !isOn
        self.value = value
        self.source = source
        self.experiment = experiment
        self.experimentResult = result
        self.ruleId = ruleId
    }
    
    init(json: [String: JSON]) {
        if let value = json["value"] {
            self.value = value
        } else {
            self.value = JSON()
        }
        if let on = json["on"] {
            self.isOn = on.boolValue
        } else {
            self.isOn = true
        }
        if let off = json["off"] {
            self.isOff = off.boolValue
        } else {
            self.isOff = false
        }
        if let source = json["source"] {
            self.source = source.stringValue
        } else {
            self.source = ""
        }
        if let experiment = json["experiment"] {
            self.experiment = Experiment(json: experiment.dictionaryValue)
        } else {
            self.experiment = nil
        }
        if let experimentResult = json["experimentResult"] {
            self.experimentResult = ExperimentResult(json: experimentResult.dictionaryValue)
        } else {
            self.experimentResult = nil
        }
        if let ruleId = json["ruleId"] {
            self.ruleId = ruleId.stringValue
        } else {
            self.ruleId = ""
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case value, isOn = "on", isOff = "off", source, experiment, experimentResult, ruleId
    }
}
