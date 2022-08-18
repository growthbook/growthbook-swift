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

/// Double Tuple for GrowthBook Ranges
typealias BucketRange = (Float, Float)

/// GrowthBook Error Class to handle any error / exception scenario
@objc public enum SDKError: NSInteger, Error {
    case failedToLoadData = 0
    case failedParsedData = 1
}
