import Foundation

/// Constants Class - GrowthBook
public enum Constants {
    /// ID Attribute Key
    public static let idAttributeKey = "id"
    /// Identifier for Caching Feature Data in Internal Storage File
    public static let featureCache = "FeatureCache"
}

/// Type Alias for Feature in GrowthBook
typealias Features = [String: Feature]

/// Type Alias for Condition Element in GrowthBook Rules
typealias Condition = JSON

/// Handler for Refresh Cache Request
///
/// It updates back whether cache was refreshed or not
public typealias CacheRefreshHandler = (Bool) -> Void

/// Handler for experiment result
public typealias TrackingCallback = (Experiment, ExperimentResult) -> Void

/// Triple Tuple for GrowthBook Namespaces
///
/// It has ID, StartRange & EndRange
typealias NameSpace = (String, Float, Float)

/// Double Struct for GrowthBook Ranges
public struct BucketRange: Codable {
    let number1: Float
    let number2: Float
}

/// GrowthBook Error Class to handle any error / exception scenario
@objc public enum SDKError: NSInteger, Error {
    case failedToLoadData = 0
    case failedParsedData = 1
    case failedMissingKey = 2
}

/// Meta info about the variations
public struct VariationMeta: Codable {
    /// Used to implement holdout groups
    let passthrough: Bool?
    /// A unique key for this variation
    let key: String?
    /// A human-readable name for this variation
    let name: String?
}

///Used for remote feature evaluation to trigger the `TrackingCallback`
public struct TrackData: Codable {
    let experiment: Experiment
    let result: ExperimentResult
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
    
    init(attribute: String?, seed: String, hashVersion: Float, ranges: [BucketRange]) {
        self.attribute = attribute
        self.seed = seed
        self.hashVersion = hashVersion
        self.ranges = ranges
    }
}
