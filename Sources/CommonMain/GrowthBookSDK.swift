import Foundation

/// GrowthBookBuilder - Root Class for SDK Initializers for GrowthBook SDK
protocol GrowthBookProtocol: AnyObject {
    var growthBookBuilderModel: GrowthBookModel { get set }
    
    func setForcedVariations(forcedVariations: [String: Int]) -> GrowthBookBuilder
    func setQAMode(isEnabled: Bool) -> GrowthBookBuilder
    func setEnabled(isEnabled: Bool) -> GrowthBookBuilder
    func initializer() -> GrowthBookSDK
    
}

public struct GrowthBookModel {
    var apiHost: String?
    var streamingHost: String?
    var clientKey: String?
    var encryptionKey: String?
    var features: Data?
    var attributes: JSON
    var trackingClosure: TrackingCallback
    var logLevel: Level = .info
    
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON?
    var cacheDirectory: CacheDirectory = .applicationSupport
    var stickyBucketService: StickyBucketServiceProtocol?
    var backgroundSync: Bool
    var remoteEval: Bool
    var apiRequestHeaders: [String: String]? = nil
    var streamingHostRequestHeaders: [String: String]? = nil
    var forcedFeatureValues: JSON?
}

/// GrowthBookBuilder - inItializer for GrowthBook SDK for Apps
/// - HostURL - Server URL
/// - EncryptionKey - Key for decrypting encrypted feature from API
/// - UserAttributes - User Attributes
/// - Tracking Closure - Track Events for Experiments
@objc public class GrowthBookBuilder: NSObject, GrowthBookProtocol {
    var growthBookBuilderModel: GrowthBookModel
    
    private var refreshHandler: CacheRefreshHandler?
    private var networkDispatcher: NetworkProtocol = CoreNetworkClient()
    
    private var cachingManager: CachingLayer
    private var evalContext: EvalContext?
    
    @objc public init(
        apiHost: String? = nil,
        clientKey: String? = nil,
        encryptionKey: String? = nil,
        attributes: [String: Any],
        features: Data? = nil,
        trackingCallback: @escaping TrackingCallback,
        refreshHandler: CacheRefreshHandler? = nil,
        backgroundSync: Bool = false,
        remoteEval: Bool = false,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil
    ) {
        growthBookBuilderModel = GrowthBookModel(
            apiHost: apiHost,
            clientKey: clientKey,
            encryptionKey: encryptionKey,
            features: features,
            attributes: JSON(attributes),
            trackingClosure: trackingCallback,
            backgroundSync: backgroundSync,
            remoteEval: remoteEval,
            apiRequestHeaders: apiRequestHeaders,
            streamingHostRequestHeaders: streamingHostRequestHeaders)
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
            apiRequestHeaders: apiRequestHeaders ?? [:],
            streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
        )
        self.cachingManager = CachingManager(apiKey: clientKey)
    }
    
    @objc public init(
        features: Data,
        attributes: [String: Any],
        trackingCallback: @escaping TrackingCallback,
        refreshHandler: CacheRefreshHandler? = nil,
        backgroundSync: Bool,
        remoteEval: Bool = false,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil
    ) {
        growthBookBuilderModel = GrowthBookModel(
            features: features,
            attributes: JSON(attributes),
            trackingClosure: trackingCallback,
            backgroundSync: backgroundSync,
            remoteEval: remoteEval,
            apiRequestHeaders: apiRequestHeaders,
            streamingHostRequestHeaders: streamingHostRequestHeaders
        )
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
            apiRequestHeaders: apiRequestHeaders ?? [:],
            streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
        )
        self.cachingManager = CachingManager()
    }
    
    init(
        apiHost: String,
        clientKey: String,
        encryptionKey: String? = nil,
        attributes: JSON,
        trackingCallback: @escaping TrackingCallback,
        refreshHandler: CacheRefreshHandler?,
        backgroundSync: Bool,
        remoteEval: Bool = false,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil
    ) {
        growthBookBuilderModel = GrowthBookModel(
            apiHost: apiHost,
            clientKey: clientKey,
            encryptionKey: encryptionKey,
            attributes: JSON(attributes),
            trackingClosure: trackingCallback,
            backgroundSync: backgroundSync,
            remoteEval: remoteEval,
            apiRequestHeaders: apiRequestHeaders,
            streamingHostRequestHeaders: streamingHostRequestHeaders
        )
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
            apiRequestHeaders: apiRequestHeaders ?? [:],
            streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
        )
        self.cachingManager = CachingManager(apiKey: clientKey)
    }
    
    /// Set Refresh Handler - Will be called when cache is refreshed
    @objc public func setRefreshHandler(refreshHandler: @escaping CacheRefreshHandler) -> GrowthBookBuilder {
        self.refreshHandler = refreshHandler
        return self
    }
    
    /// Set Network Client - Network Client for Making API Calls
    @objc public func setNetworkDispatcher(networkDispatcher: NetworkProtocol) -> GrowthBookBuilder {
        self.networkDispatcher = networkDispatcher
        return self
    }
    
    /// Set Caching Manager - Caching Client for saving fetched features
    @objc public func setCachingManager(cachingManager: CachingLayer) -> GrowthBookBuilder {
        self.cachingManager = cachingManager
        return self
    }
    
    @objc public func setStickyBucketService() -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = StickyBucketService(cacheKey: growthBookBuilderModel.clientKey)
        return self
    }
    
    @objc public func setStickyBucketService(stickyBucketService: StickyBucketServiceProtocol) -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = stickyBucketService
        return self
    }
    
    @objc public func setStickyBucketService(cacheKey: String) -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = StickyBucketService(cacheKey: cacheKey)
        return self
    }
    
    /// Set log level for SDK Logger
    ///
    /// By default log level is set to `info`
    @objc public func setLogLevel(_ level: LoggerLevel) -> GrowthBookBuilder {
        growthBookBuilderModel.logLevel = GBLogger.getLoggingLevel(from: level)
        return self
    }
    
    @objc public func setForcedVariations(forcedVariations: [String: Int]) -> GrowthBookBuilder {
        growthBookBuilderModel.forcedVariations = JSON(forcedVariations)
        return self
    }
    
    @objc public func setQAMode(isEnabled: Bool) -> GrowthBookBuilder {
        growthBookBuilderModel.isQaMode = isEnabled
        return self
    }
    
    @objc public func setEnabled(isEnabled: Bool) -> GrowthBookBuilder {
        growthBookBuilderModel.isEnabled = isEnabled
        return self
    }
    
    @objc public func setSystemCacheDirectory(_ systemDirectory: CacheDirectory) -> GrowthBookBuilder {
        cachingManager.setSystemCacheDirectory(systemDirectory)
        return self
    }
    
    @objc public func setCustomCacheDirectory(_ customDirectory: String) -> GrowthBookBuilder {
        cachingManager.setCustomCachePath(customDirectory)
        return self
    }
    
    @objc public func setStreamingHost(streamingHost: String) -> GrowthBookBuilder {
        growthBookBuilderModel.streamingHost = streamingHost
        return self
    }
    
    @objc public func setForcedFeatures(forcedFeatures: [String: Any]) -> GrowthBookBuilder {
        growthBookBuilderModel.forcedFeatureValues = JSON(forcedFeatures)
        return self
    }
    
    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            apiHost: growthBookBuilderModel.apiHost,
            streamingHost : growthBookBuilderModel.streamingHost,
            clientKey: growthBookBuilderModel.clientKey,
            encryptionKey: growthBookBuilderModel.encryptionKey,
            isEnabled: growthBookBuilderModel.isEnabled,
            attributes: growthBookBuilderModel.attributes,
            forcedVariations: growthBookBuilderModel.forcedVariations,
            stickyBucketService: growthBookBuilderModel.stickyBucketService,
            isQaMode: growthBookBuilderModel.isQaMode,
            trackingClosure: growthBookBuilderModel.trackingClosure,
            backgroundSync: growthBookBuilderModel.backgroundSync,
            remoteEval: growthBookBuilderModel.remoteEval,
            forcedFeatureValues: growthBookBuilderModel.forcedFeatureValues
        )
        
        if let clientKey = growthBookBuilderModel.clientKey {
            cachingManager.setCacheKey(clientKey)
        }
        
        if let features = growthBookBuilderModel.features {
            cachingManager.saveContent(fileName: Constants.featureCache, content: features)
        }
        
        return GrowthBookSDK(context: gbContext, refreshHandler: refreshHandler, networkDispatcher: networkDispatcher, cachingManager: cachingManager)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject, FeaturesFlowDelegate {
    var refreshHandler: CacheRefreshHandler?
    private var subscriptions: [ExperimentRunCallback] = []
    private var networkDispatcher: NetworkProtocol
    public var gbContext: Context
    private var featureVM: FeaturesViewModel!
    private var attributeOverrides: JSON = JSON()
    private var savedGroupsValues: JSON?
    private var evalContext: EvalContext!
    var cachingManager: CachingLayer
    
    init(context: Context,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil,
         savedGroups: JSON? = nil,
         cachingManager: CachingLayer) {
        gbContext = context
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.savedGroupsValues = savedGroups
        self.cachingManager = cachingManager
        super.init()
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher), cachingManager: cachingManager)
        if let features = features {
            gbContext.features = features
        } else {
            featureVM.encryptionKey = context.encryptionKey ?? ""
            refreshCache()
        }
        
        if let savedGroups {
            context.savedGroups = savedGroups
        }
        
        // if the SSE URL is available and background sync variable is set to true, then we have to connect to SSE Server
        if let sseURL = context.getSSEUrl(), context.backgroundSync {
            featureVM.connectBackgroundSync(sseUrl: sseURL)
        }
        
        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel
        
        evalContext = Utils.initializeEvalContext(context: context)
        if let service = gbContext.stickyBucketService,
           let docs = gbContext.stickyBucketAssignmentDocs {
            for (_, doc) in docs {
                service.saveAssignments(doc: doc) { _ in
                    // Ignore hydration errors
                }
            }
        }
        refreshStickyBucketService()
        
    }
    
    /// Manually Refresh Cache
    @objc public func refreshCache() {
        if gbContext.remoteEval {
            refreshForRemoteEval()
        } else {
            featureVM.fetchFeatures(apiUrl: gbContext.getFeaturesURL())
        }
    }
    
    /// This function removes all files and subdirectories within the designated cache directory, which is a specific subdirectory within the app's cache directory.
    @objc public func clearCache() {
        cachingManager.clearCache()
    }
    
    /// Get Context - Holding the complete data regarding cached features & attributes etc.
    @objc public func getGBContext() -> Context {
        return gbContext
    }
    
    public func getGBAttributes() -> JSON {
        return gbContext.attributes
    }
    
    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        return gbContext.features
    }
    
    @objc public func subscribe(_ result: @escaping ExperimentRunCallback) {
        self.subscriptions.append(result)
    }
    
    @objc public func clearSubscriptions() {
        self.subscriptions.removeAll()
    }
    
    /// Get the value of the feature with a fallback
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        let context = getEvalContext()
        let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
        // Update evalContext with any sticky bucket changes
        evalContext.userContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        gbContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        return result.value ?? defaultValue
    }
    
    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        gbContext.features = features
        evalContext = Utils.initializeEvalContext(context: gbContext)
        refreshStickyBucketService()
        if isRemote {
            refreshHandler?(true)
        }
    }
    
    /// The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }
        
        gbContext.features = features
        evalContext = Utils.initializeEvalContext(context: gbContext)
        refreshStickyBucketService()
    }
    
    @objc public func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(false)
        }
    }
    
    private func getEvalContext() -> EvalContext {
        evalContext.stackContext = StackContext()
        evalContext.userContext = getUserContext()
        evalContext.globalContext.features = gbContext.features
        return evalContext
    }
    
    private func getUserContext() -> UserContext {
        return UserContext(
            attributes: evalContext.userContext.attributes,
            stickyBucketAssignmentDocs: evalContext.userContext.stickyBucketAssignmentDocs,
            forcedVariations: evalContext.userContext.forcedVariations,
            forcedFeatureValues: gbContext.forcedFeatureValues
        )
    }
    
    @objc public func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        refreshHandler?(false)
    }
    
    public func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        gbContext.savedGroups = savedGroups
        refreshHandler?(true)
    }
    
    /// If remote eval is enabled, send needed data to backend to proceed remote evaluation
    @objc public func refreshForRemoteEval() {
        if !gbContext.remoteEval { return }
        let forcedFeaturesArray = convertForcedFeaturesToArray(gbContext.forcedFeatureValues)
        let forcedFeaturesJson = JSON(forcedFeaturesArray ?? [])
        
        
        let payload = RemoteEvalParams(attributes: gbContext.attributes, forcedFeatures: forcedFeaturesJson, forcedVariations: gbContext.forcedVariations )
        featureVM.fetchFeatures(apiUrl: gbContext.getRemoteEvalUrl(), remoteEval: gbContext.remoteEval, payload: payload)
    }
    
    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    @objc public func evalFeature(id: String) -> FeatureResult {
        let context = getEvalContext()
        let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
        // Update evalContext with any sticky bucket changes
        evalContext.userContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        gbContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        return result
    }
    
    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    @objc public func isOn(feature id: String) -> Bool {
        return evalFeature(id: id).isOn
    }
    
    /// The run method takes an Experiment object and returns an experiment result
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        let context = getEvalContext()
        let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: experiment)
        // Update evalContext with any sticky bucket changes
        evalContext.userContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        gbContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs
        
        self.subscriptions.forEach { subscription in
            subscription(experiment, result)
        }
        
        return result
    }
    
    /// The setForcedFeatures method updates forced features
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        gbContext.forcedFeatureValues = JSON(forcedFeatures)
        refreshForRemoteEval()
    }
    
    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    @objc public func setAttributes(attributes: Any) {
        gbContext.attributes = JSON(attributes)
        evalContext = Utils.initializeEvalContext(context: gbContext)
        refreshStickyBucketService()
    }
    
    /// Merges the provided user attributes with the existing ones.
    /// - Throws: `SwiftyJSON.Error.wrongType` if the top-level JSON types differ
    @objc public func appendAttributes(attributes: Any) throws {
        let updatedAttributes = try gbContext.attributes.merged(with: JSON(attributes))
        gbContext.attributes = updatedAttributes
        evalContext = Utils.initializeEvalContext(context: gbContext)
        refreshStickyBucketService()
    }
    
    @objc public func setAttributeOverrides(overrides: Any) {
        attributeOverrides = JSON(overrides)
        if gbContext.stickyBucketService != nil {
            refreshStickyBucketService()
        }
        evalContext = Utils.initializeEvalContext(context: gbContext)
        refreshForRemoteEval()
    }
    
    /// The setForcedVariations method updates forced variations and makes API call if remote eval is enabled
    @objc public func setForcedVariations(forcedVariations: Any) {
        gbContext.forcedVariations = JSON(forcedVariations)
        refreshForRemoteEval()
    }
    
    /// Updates API request headers for dynamic header management
    @objc public func updateApiRequestHeaders(_ headers: [String: String]) {
        if let networkClient = networkDispatcher as? CoreNetworkClient {
            networkClient.apiRequestHeaders = headers
        }
    }
    
    /// Updates streaming host request headers for SSE connections
    @objc public func updateStreamingHostRequestHeaders(_ headers: [String: String]) {
        if let networkClient = networkDispatcher as? CoreNetworkClient {
            networkClient.streamingHostRequestHeaders = headers
        }
    }
    
    @objc func featuresAPIModelSuccessfully(model: FeaturesDataModel) {
        refreshStickyBucketService(model)
    }
    
    @objc private func refreshStickyBucketService(_ data: FeaturesDataModel? = nil) {
        if (evalContext != nil && evalContext.options.stickyBucketService != nil) {
            Utils.refreshStickyBuckets(context: getEvalContext(), attributes: evalContext.userContext.attributes, data: data)
        }
    }
    
    private func convertForcedFeaturesToArray(_ forcedFeatures: JSON?) -> [[JSON]]? {
        guard let features = forcedFeatures?.dictionaryValue, !features.isEmpty else {
            return nil
        }
        
        let result = features.map { key, value -> [JSON] in
            return [JSON(key), value]
        }
        
        return result
    }
}
