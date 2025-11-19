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
        let globalConfig = GlobalConfig(
            apiHost: growthBookBuilderModel.apiHost, 
            clientKey: growthBookBuilderModel.clientKey, 
            encryptionKey: growthBookBuilderModel.encryptionKey, 
            isEnabled: growthBookBuilderModel.isEnabled, 
            isQaMode: growthBookBuilderModel.isQaMode,
            backgroundSync: growthBookBuilderModel.backgroundSync,
            remoteEval: growthBookBuilderModel.remoteEval,
            trackingClosure: growthBookBuilderModel.trackingClosure,
            stickyBucketService: growthBookBuilderModel.stickyBucketService
        )

        // Parse features from Data if available
        var initialFeatures: Features = [:]
        if let featuresData = growthBookBuilderModel.features {
            let decoder = JSONDecoder()
            // Try to decode as FeaturesDataModel first (API format)
            if let featuresModel = try? decoder.decode(FeaturesDataModel.self, from: featuresData),
               let features = featuresModel.features {
                initialFeatures = features
            } else if let features = try? decoder.decode(Features.self, from: featuresData) {
                // Fallback: try to decode directly as Features dictionary
                initialFeatures = features
            }
        }

        let evaluationData = EvaluationData(
            streamingHost: growthBookBuilderModel.streamingHost,
            attributes: growthBookBuilderModel.attributes,
            forcedVariations: growthBookBuilderModel.forcedVariations,
            stickyBucketAssignmentDocs: nil,
            stickyBucketIdentifierAttributes: nil,
            features: initialFeatures,
            savedGroups: nil,
            url: nil,
            forcedFeatureValues: growthBookBuilderModel.forcedFeatureValues
        )

        let contextManager = ContextManager(globalConfig: globalConfig, evalData: evaluationData)
        
        if let clientKey = growthBookBuilderModel.clientKey {
            cachingManager.setCacheKey(clientKey)
        }
        
        if let features = growthBookBuilderModel.features {
            cachingManager.saveContent(fileName: Constants.featureCache, content: features)
        }
        
        return GrowthBookSDK(contextManager: contextManager, refreshHandler: refreshHandler, networkDispatcher: networkDispatcher, cachingManager: cachingManager)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject, FeaturesFlowDelegate {
    var refreshHandler: CacheRefreshHandler?
    private var subscriptions: [ExperimentRunCallback] = []
    private var networkDispatcher: NetworkProtocol
    private var contextManager: ContextManager
    private var featureVM: FeaturesViewModel!
    private var attributeOverrides: JSON = JSON()
    private var savedGroupsValues: JSON?
    private var evalContext: EvalContext!
    var cachingManager: CachingLayer
    
    init(contextManager: ContextManager,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil,
         savedGroups: JSON? = nil,
         cachingManager: CachingLayer) {
        self.contextManager = contextManager
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.savedGroupsValues = savedGroups
        self.cachingManager = cachingManager
        super.init()
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher), cachingManager: cachingManager)
        
        let evalData = contextManager.getEvaluationData()
        let globalConfig = contextManager.getGlobalConfig()
        
        if let features = features {
            contextManager.updateEvalData { data in
                data.features = features
            }
        } else {
            featureVM.encryptionKey = globalConfig.encryptionKey ?? ""
            refreshCache()
        }
        
        if let savedGroups {
            contextManager.updateEvalData { data in
                data.savedGroups = savedGroups
            }
        }
        
        // if the SSE URL is available and background sync variable is set to true, then we have to connect to SSE Server
        if let sseURL = evalData.streamingHost, globalConfig.backgroundSync {
            featureVM.connectBackgroundSync(sseUrl: sseURL)
        }
        
        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel
        
        // Initialize evalContext from contextManager
        evalContext = contextManager.getEvalContext()
        
        if let service = globalConfig.stickyBucketService,
           let docs = evalData.stickyBucketAssignmentDocs {
            for (_, doc) in docs {
                service.saveAssignments(doc: doc) { _ in
                    // Ignore hydration errors
                }
            }
        }
        refreshStickyBucketService()
        
    }
    
    // Convenience init for backward compatibility
    convenience init(context: Context,
                     refreshHandler: CacheRefreshHandler? = nil,
                     logLevel: Level = .info,
                     networkDispatcher: NetworkProtocol = CoreNetworkClient(),
                     features: Features? = nil,
                     savedGroups: JSON? = nil,
                     cachingManager: CachingLayer) {
        // Create GlobalConfig from Context
        let globalConfig = GlobalConfig(
            apiHost: context.apiHost,
            clientKey: context.clientKey,
            encryptionKey: context.encryptionKey,
            isEnabled: context.isEnabled,
            isQaMode: context.isQaMode,
            backgroundSync: context.backgroundSync,
            remoteEval: context.remoteEval,
            trackingClosure: context.trackingClosure,
            stickyBucketService: context.stickyBucketService
        )
        
        // Create EvaluationData from Context
        let evaluationData = EvaluationData(
            streamingHost: context.streamingHost,
            attributes: context.attributes,
            forcedVariations: context.forcedVariations,
            stickyBucketAssignmentDocs: context.stickyBucketAssignmentDocs,
            stickyBucketIdentifierAttributes: context.stickyBucketIdentifierAttributes,
            features: features ?? context.features,
            savedGroups: savedGroups ?? context.savedGroups,
            url: context.url,
            forcedFeatureValues: context.forcedFeatureValues
        )
        
        // Create ContextManager
        let contextManager = ContextManager(globalConfig: globalConfig, evalData: evaluationData)
        
        // Call main init
        self.init(
            contextManager: contextManager,
            refreshHandler: refreshHandler,
            logLevel: logLevel,
            networkDispatcher: networkDispatcher,
            features: features,
            savedGroups: savedGroups,
            cachingManager: cachingManager
        )
    }
    
    /// Manually Refresh Cache
    @objc public func refreshCache() {
        let globalConfig = contextManager.getGlobalConfig()
        if globalConfig.remoteEval {
            refreshForRemoteEval()
        } else {
            featureVM.fetchFeatures(apiUrl: contextManager.getFeaturesURL())
        }
    }
    
    /// This function removes all files and subdirectories within the designated cache directory, which is a specific subdirectory within the app's cache directory.
    @objc public func clearCache() {
        cachingManager.clearCache()
    }
    
    /// Get Context - Holding the complete data regarding cached features & attributes etc.
    /// Note: This method is kept for backward compatibility but returns a Context created from ContextManager
    @objc public func getGBContext() -> Context {
        let globalConfig = contextManager.getGlobalConfig()
        let evalData = contextManager.getEvaluationData()
        return Context(
            apiHost: globalConfig.apiHost,
            streamingHost: evalData.streamingHost,
            clientKey: globalConfig.clientKey,
            encryptionKey: globalConfig.encryptionKey,
            isEnabled: globalConfig.isEnabled,
            attributes: evalData.attributes,
            forcedVariations: evalData.forcedVariations,
            stickyBucketAssignmentDocs: evalData.stickyBucketAssignmentDocs,
            stickyBucketIdentifierAttributes: evalData.stickyBucketIdentifierAttributes,
            stickyBucketService: globalConfig.stickyBucketService,
            isQaMode: globalConfig.isQaMode,
            trackingClosure: globalConfig.trackingClosure,
            features: evalData.features,
            backgroundSync: globalConfig.backgroundSync,
            remoteEval: globalConfig.remoteEval,
            savedGroups: evalData.savedGroups,
            url: evalData.url,
            forcedFeatureValues: evalData.forcedFeatureValues
        )
    }
    
    public func getGBAttributes() -> JSON {
        return contextManager.getEvaluationData().attributes
    }
    
    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        return contextManager.getEvaluationData().features
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
        contextManager.syncFromEvaluation(context)
        return result.value ?? defaultValue
    }
    
    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        contextManager.updateEvalData { data in
            data.features = features
        }
        refreshStickyBucketService()
        if isRemote {
            refreshHandler?(true)
        }
    }
    
    /// The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }
        
        contextManager.updateEvalData { data in
            data.features = features
        }

        refreshStickyBucketService()
    }
    
    @objc public func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(false)
        }
    }
    
    private func getEvalContext() -> EvalContext {
        return contextManager.getEvalContext()
    }
    
    @objc public func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        refreshHandler?(false)
    }
    
    public func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        contextManager.updateEvalData { data in
            data.savedGroups = savedGroups
        }
        refreshHandler?(true)
    }
    
    /// If remote eval is enabled, send needed data to backend to proceed remote evaluation
    @objc public func refreshForRemoteEval() {
        let globalConfig = contextManager.getGlobalConfig()
        let evalData = contextManager.getEvaluationData()
        if !globalConfig.remoteEval { return }
        let forcedFeaturesArray = convertForcedFeaturesToArray(evalData.forcedFeatureValues)
        let forcedFeaturesJson = JSON(forcedFeaturesArray ?? [])
        
        
        let payload = RemoteEvalParams(attributes: evalData.attributes, forcedFeatures: forcedFeaturesJson, forcedVariations: evalData.forcedVariations )
        featureVM.fetchFeatures(apiUrl: contextManager.getRemoteEvalUrl(), remoteEval: globalConfig.remoteEval, payload: payload)
    }
    
    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    @objc public func evalFeature(id: String) -> FeatureResult {
        let context = getEvalContext()
        let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
        // Update evalContext with any sticky bucket changes
        contextManager.syncFromEvaluation(context)
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
        contextManager.syncFromEvaluation(context)
        
        self.subscriptions.forEach { subscription in
            subscription(experiment, result)
        }
        
        return result
    }
    
    /// The setForcedFeatures method updates forced features
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        contextManager.updateEvalData { data in
            data.forcedFeatureValues = JSON(forcedFeatures)
        }
        refreshForRemoteEval()
    }
    
    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    @objc public func setAttributes(attributes: Any) {
        contextManager.updateEvalData { data in
            data.attributes = JSON(attributes)
        }
        refreshStickyBucketService()
    }
    
    /// Merges the provided user attributes with the existing ones.
    /// - Throws: `SwiftyJSON.Error.wrongType` if the top-level JSON types differ
    @objc public func appendAttributes(attributes: Any) throws {
        let evalData = contextManager.getEvaluationData()
        let updatedAttributes = try evalData.attributes.merged(with: JSON(attributes))
        contextManager.updateEvalData { data in
            data.attributes = updatedAttributes
        }
        refreshStickyBucketService()
    }
    
    @objc public func setAttributeOverrides(overrides: Any) {
        attributeOverrides = JSON(overrides)
        let globalConfig = contextManager.getGlobalConfig()
        if globalConfig.stickyBucketService != nil {
            refreshStickyBucketService()
        }
        refreshForRemoteEval()
    }
    
    /// The setForcedVariations method updates forced variations and makes API call if remote eval is enabled
    @objc public func setForcedVariations(forcedVariations: Any) {
        contextManager.updateEvalData { data in
            data.forcedVariations = JSON(forcedVariations)
        }
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
        let context = getEvalContext()
        let globalConfig = contextManager.getGlobalConfig()
        if globalConfig.stickyBucketService != nil {
            let evalData = contextManager.getEvaluationData()
            Utils.refreshStickyBuckets(context: context, attributes: evalData.attributes, data: data)
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
