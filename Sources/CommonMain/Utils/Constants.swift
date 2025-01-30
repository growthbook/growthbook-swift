import Foundation

/// Constants Class - GrowthBook
public enum Constants {
    /// ID Attribute Key
    public static let idAttributeKey = "id"
    /// Identifier for Caching Feature Data in Internal Storage File
    public static let featureCache = "FeatureCache"
    
    public static let savedGroupsCache = "SavedGroupsCache"
}

/// Type Alias for Feature in GrowthBook
public typealias Features = [String: Feature]

/// Type Alias for Condition Element in GrowthBook Rules
typealias Condition = JSON

public struct ParentConditionInterface: Codable {
    public let id: String
    public let condition: JSON
    public let gate: Bool?
    
    init(json: [String: JSON]) {
        self.id = json["id"]?.stringValue ?? ""
        self.condition = json["condition"] ?? JSON()
        self.gate = json["gate"]?.boolValue
    }
}

/// Handler for Refresh Cache Request
/// 
/// It updates back whether cache was refreshed or not
public typealias CacheRefreshHandler = (Bool) -> Void

/// Handler for experiment result
public typealias TrackingCallback = (Experiment, ExperimentResult) -> Void

/// Handler for subscribed experiment result
public typealias ExperimentRunCallback = (Experiment, ExperimentResult) -> Void

/// Triple Tuple for GrowthBook Namespaces
///
/// It has ID, StartRange & EndRange
typealias NameSpace = (String, Float, Float)

/// Double Struct for GrowthBook Ranges
public struct BucketRange: Codable, Sendable {
    let number1: Float
    let number2: Float
    
    init(number1: Float, number2: Float) {
        self.number1 = number1
        self.number2 = number2
    }
    
    init(json: JSON) {
        if json.arrayValue.isEmpty {
            number1 = 0
            number2 = 0
        } else {
            self.number1 = json.arrayValue[0].floatValue
            self.number2 = json.arrayValue[1].floatValue
        }
    }
}

/// GrowthBook Error Class to handle any error / exception scenario
@objc public enum SDKError: NSInteger, Error, Sendable {
    case failedToLoadData = 0
    case failedParsedData = 1
    case failedMissingKey = 2
    case failedEncryptedFeatures = 3
    case failedEncryptedSavedGroups = 4
}

/// Meta info about the variations
public struct VariationMeta: Codable, Sendable {
    /// Used to implement holdout groups
    let passthrough: Bool?
    /// A unique key for this variation
    let key: String?
    /// A human-readable name for this variation
    let name: String?
    
    init(json: [String: JSON]) {
        self.passthrough = json["passthrough"]?.boolValue
        self.key = json["key"]?.stringValue
        self.name = json["name"]?.stringValue
    }
}

public struct Track: Codable {
    public let experiment: Experiment?
    public let result: FeatureResult?
    
    init(json: [String: JSON]) {
        experiment = Experiment(json: json["experiment"]?.dictionaryValue ?? [:])
        result = FeatureResult(json: json["result"]?.dictionaryValue ?? [:])
    }
}

///Used for remote feature evaluation to trigger the `TrackingCallback`
public struct TrackData: Codable {
    let experiment: Experiment
    let result: ExperimentResult
    
    init(json: [String: JSON]) {
        // TODO: - Need to check it
        experiment = Experiment(json: json["experiment"]?.dictionaryValue ?? [:])
        result = ExperimentResult(json: json["result"]?.dictionaryValue ?? [:])
    }
}

/// Object used for mutual exclusion and filtering users out of experiments based on random hashes.
@objc public class Filter: NSObject, Codable {
    /// The attribute to use (default to `"id"`)
    var attribute: String?
    /// The seed used in the hash
    var seed: String
    /// The hash version to use (default to `2`)
    var hashVersion: Float
    /// Array of ranges that are included
    var ranges: [BucketRange]
    
    var fallbackAttribute: String?
    
    init(attribute: String?, seed: String, hashVersion: Float, ranges: [BucketRange], fallbackAttribute: String?) {
        self.attribute = attribute
        self.seed = seed
        self.hashVersion = hashVersion
        self.ranges = ranges
        self.fallbackAttribute = fallbackAttribute
    }
    
    init(json: [String: JSON]) {
        self.attribute = json["attribute"]?.stringValue
        self.seed = json["seed"]?.stringValue ?? ""
        self.hashVersion = json["hashVersion"]?.floatValue ?? 2.0
        self.ranges = json["ranges"]?.map({ key, value in
            BucketRange(json: value)
        }) ?? []
    }
}
