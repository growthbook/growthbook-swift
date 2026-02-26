import Foundation

/// Mutable evaluation data for GrowthBook SDK.
///
/// This class holds all data that can change during SDK runtime, such as:
/// - Features fetched from the API
/// - User attributes
/// - Forced variations and feature values
/// - Sticky bucket assignments
///
/// **Key Characteristics:**
/// - All properties are `var` (mutable)
/// - Updated throughout SDK lifecycle
/// - Managed by `ContextManager` for controlled updates
///
/// **Example:**
/// ```swift
/// let evalData = EvaluationData(
///     streamingHost: "https://streaming.growthbook.io",
///     attributes: JSON(["id": "user123", "email": "user@example.com"]),
///     forcedVariations: nil,
///     stickyBucketAssignmentDocs: nil,
///     stickyBucketIdentifierAttributes: nil,
///     features: [:],
///     savedGroups: nil,
///     url: nil,
///     forcedFeatureValues: nil
/// )
///
/// // Update data through ContextManager
/// contextManager.updateEvalData { data in
///     data.features = newFeatures
///     data.attributes = JSON(["id": "user456"])
/// }
/// ```
@objc public class EvaluationData: NSObject {
  /// Your streaming host
  public var streamingHost: String?
  /// Map of user attributes that are used to assign variations
  public var attributes: JSON
  /// Force specific experiments to always assign a specific variation (used for QA)
  public var forcedVariations: JSON?
  /// If true, random assignment is disabled and only explicitly forced variations are used.
  /// Stick bucketing specific configurations for specific keys
  public var stickyBucketAssignmentDocs: [String: StickyAssignmentsDocument]?
  /// Features that uses sticky bucketing
  public var stickyBucketIdentifierAttributes: [String]?
  /// Keys are unique identifiers for the features and the values are Feature objects.
  /// Feature definitions - To be pulled from API / Cache
  var features: Features
  /// Target the same group of users across multiple features and experiments with Saved Groups
  public var savedGroups: JSON?
  
  public var url: String? = nil

  public var forcedFeatureValues: JSON? = nil
  
  init(
    streamingHost: String?,
    attributes: JSON,
    forcedVariations: JSON?,
    stickyBucketAssignmentDocs:  [String: StickyAssignmentsDocument]? = nil,
    stickyBucketIdentifierAttributes: [String]? = nil,
    features: Features = [:],
    savedGroups: JSON? = nil,
    url: String? = nil,
    forcedFeatureValues: JSON? = nil) {
      self.streamingHost = streamingHost
      self.attributes = attributes
      self.forcedVariations = forcedVariations
      self.stickyBucketAssignmentDocs = stickyBucketAssignmentDocs
      self.stickyBucketIdentifierAttributes = stickyBucketIdentifierAttributes
      self.features = features
      self.savedGroups = savedGroups
      self.url = url
      self.forcedFeatureValues = forcedFeatureValues
    }
}