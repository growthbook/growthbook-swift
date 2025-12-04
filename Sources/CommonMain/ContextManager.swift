import Foundation

/// Manages the global configuration and evaluation data for GrowthBook SDK.
///
/// This class is responsible for:
/// - Managing immutable global configuration (`GlobalConfig`)
/// - Managing mutable evaluation data (`EvaluationData`)
/// - Creating and caching `EvalContext` instances
/// - Providing controlled access to internal state
/// - Automatically invalidating cache when data changes
///
/// **Key Features:**
/// - Separation of concerns: Global config (immutable) vs Evaluation data (mutable)
/// - Automatic cache invalidation on data updates
/// - Thread-safe context creation with caching
/// - Clean API for updating data through closures
///
/// **Example Usage:**
/// ```swift
/// let globalConfig = GlobalConfig(...)
/// let evalData = EvaluationData(...)
/// let manager = ContextManager(globalConfig: globalConfig, evalData: evalData)
///
/// // Update data
/// manager.updateEvalData { data in
///     data.features = newFeatures
///     data.attributes = newAttributes
/// }
///
/// // Get evaluation context
/// let context = manager.getEvalContext()
/// ```
@objc public class ContextManager: NSObject {
  private let globalConfig: GlobalConfig
  private var evalData: EvaluationData
  private var cachedEvalContext: EvalContext?

  /// Initializes a new ContextManager with global configuration and evaluation data.
  ///
  /// - Parameters:
  ///   - globalConfig: Immutable global configuration (API host, client key, etc.)
  ///   - evalData: Mutable evaluation data (features, attributes, etc.)
  init(globalConfig: GlobalConfig, evalData: EvaluationData) {
    self.globalConfig = globalConfig
    self.evalData = evalData
  }

  /// Creates a new `EvalContext` from the current configuration and data.
  ///
  /// The context is cached and reused until invalidated by data updates.
  /// Each call returns the same cached instance until `updateEvalData()` or
  /// `syncFromEvaluation()` is called, which invalidates the cache.
  ///
  /// - Returns: A new or cached `EvalContext` instance
  ///
  /// **Note:** The `StackContext` is reset on each new context creation,
  /// ensuring clean state for feature evaluation.
  public func getEvalContext() -> EvalContext {
    if let cached = cachedEvalContext {
      return cached
    }
    
    let newEvalContext = buildEvalContext()
    cachedEvalContext = newEvalContext
    return newEvalContext
  }

  /// Returns the current evaluation data.
  ///
  /// - Returns: The current `EvaluationData` instance
  ///
  /// **Note:** This returns a reference to the internal data.
  /// To modify data, use `updateEvalData()` instead of modifying directly.
  public func getEvaluationData() -> EvaluationData {
    return evalData
  }

  /// Returns the global configuration.
  ///
  /// - Returns: The `GlobalConfig` instance (immutable)
  public func getGlobalConfig() -> GlobalConfig {
    return globalConfig
  }

  /// Constructs the features API URL from the global configuration.
  ///
  /// - Returns: The features API URL in format `{apiHost}/api/features/{clientKey}`, or `nil` if `apiHost` or `clientKey` is missing
  public func getFeaturesURL() -> String? {
    if let apiHost = globalConfig.apiHost, let clientKey = globalConfig.clientKey {
      return "\(apiHost)/api/features/\(clientKey)"
    } else {
      return nil
    }
  }

  /// Constructs the remote evaluation API URL from the global configuration.
  ///
  /// - Returns: The remote eval API URL in format `{apiHost}/api/eval/{clientKey}`, or `nil` if `apiHost` or `clientKey` is missing
  public func getRemoteEvalUrl() -> String? {
    if let apiHost = globalConfig.apiHost, let clientKey = globalConfig.clientKey {
      return "\(apiHost)/api/eval/\(clientKey)"
    } else {
      return nil
    }
  }

  /// Constructs the SSE (Server-Sent Events) URL for streaming updates.
  ///
  /// Uses `streamingHost` from evaluation data if available, otherwise falls back to `apiHost` from global config.
  ///
  /// - Returns: The SSE URL in format `{host}/sub/{clientKey}`, or `nil` if host or `clientKey` is missing
  public func getSSEUrl() -> String? {
    let evalData = getEvaluationData()
    if let host = evalData.streamingHost ?? globalConfig.apiHost, let clientKey = globalConfig.clientKey {
      return "\(host)/sub/\(clientKey)"
    } else {
      return nil
    }
  }

  /// Updates the evaluation data using a closure.
  ///
  /// After the update, the cached `EvalContext` is automatically invalidated,
  /// ensuring that the next call to `getEvalContext()` will create a fresh context
  /// with the updated data.
  ///
  /// - Parameter update: A closure that receives the `EvaluationData` to modify
  ///
  /// **Example:**
  /// ```swift
  /// contextManager.updateEvalData { data in
  ///     data.features = newFeatures
  ///     data.attributes = JSON(["id": "user123"])
  ///     data.savedGroups = newSavedGroups
  /// }
  /// ```
  ///
  /// **Thread Safety:** This method should be called from the main thread or with proper synchronization.
  public func updateEvalData(_ update: (EvaluationData) -> Void) {
    update(evalData)
    invalidateCache()
  }

  /// Synchronizes sticky bucket assignment documents from an evaluation result.
  ///
  /// This method copies `stickyBucketAssignmentDocs` from the evaluation result's
  /// `userContext` back into the evaluation data, and invalidates the cache.
  ///
  /// This is typically called after feature or experiment evaluation to persist
  /// any sticky bucket assignments that were created during evaluation.
  ///
  /// - Parameter evaluationResult: The `EvalContext` from which to sync sticky bucket assignments
  ///
  /// **Example:**
  /// ```swift
  /// let context = contextManager.getEvalContext()
  /// let result = FeatureEvaluator(context: context, featureKey: "my-feature").evaluateFeature()
  /// // Sticky bucket assignments may have been created in context.userContext
  /// contextManager.syncFromEvaluation(context)
  /// ```
  public func syncFromEvaluation(_ evaluationResult: EvalContext) {
    evalData.stickyBucketAssignmentDocs = evaluationResult.userContext.stickyBucketAssignmentDocs
    invalidateCache()
  }

  /// Invalidates the cached `EvalContext`.
  ///
  /// The next call to `getEvalContext()` will create a new context.
  private func invalidateCache() {
    cachedEvalContext = nil
  }

  /// Builds a new `EvalContext` from the current `globalConfig` and `evalData`.
  ///
  /// This method creates:
  /// - `ClientOptions` from `globalConfig`
  /// - `GlobalContext` from `evalData.features` and `evalData.savedGroups`
  /// - `UserContext` from `evalData` (attributes, forced variations, etc.)
  /// - A fresh `StackContext` (reset state)
  ///
  /// - Returns: A new `EvalContext` instance
  private func buildEvalContext() -> EvalContext {
    // Create a new StackContext (reset state)
    let stackContext = StackContext()
    
    // ClientOptions is created from globalConfig
    let options = ClientOptions(
      isEnabled: globalConfig.isEnabled,
      stickyBucketAssignmentDocs: evalData.stickyBucketAssignmentDocs,
      stickyBucketIdentifierAttributes: evalData.stickyBucketIdentifierAttributes,
      stickyBucketService: globalConfig.stickyBucketService,
      isQaMode: globalConfig.isQaMode,
      url: evalData.url,
      trackingClosure: globalConfig.trackingClosure
    )
    
    // GlobalContext is created from evalData.features and evalData.savedGroups
    let globalContext = GlobalContext(
      features: evalData.features,
      savedGroups: evalData.savedGroups
    )
    
    // UserContext is created from evalData
    let userContext = UserContext(
      attributes: evalData.attributes,
      stickyBucketAssignmentDocs: evalData.stickyBucketAssignmentDocs,
      forcedVariations: evalData.forcedVariations,
      forcedFeatureValues: evalData.forcedFeatureValues
    )
    
    // Return a new EvalContext
    let evalContext = EvalContext(
      globalContext: globalContext,
      userContext: userContext,
      stackContext: stackContext,
      options: options
    )
    
    return evalContext
  }
}