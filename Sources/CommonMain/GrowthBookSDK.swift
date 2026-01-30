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
    private var ttlSeconds: Int
                        
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
        ttlSeconds: Int = 60,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil) {

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
            streamingHostRequestHeaders: streamingHostRequestHeaders
        )
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
                    apiRequestHeaders: apiRequestHeaders ?? [:],
                    streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
                )
        self.cachingManager = CachingManager(apiKey: clientKey)
        self.ttlSeconds = ttlSeconds
    }
    
    
    @objc public init(
        features: Data,
        attributes: [String: Any],
        trackingCallback: @escaping TrackingCallback,
        refreshHandler: CacheRefreshHandler? = nil,
        backgroundSync: Bool,
        remoteEval: Bool = false,
        ttlSeconds: Int = 60,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil) {
            
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
        self.ttlSeconds = ttlSeconds
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
        ttlSeconds: Int = 60,
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
        self.ttlSeconds = ttlSeconds
    }

    /// Set Refresh Handler - Will be called when cache is refreshed
    /// - Parameter refreshHandler: CacheRefreshHandler
    /// - Returns: GrowthBookBuilder
    @objc public func setRefreshHandler(refreshHandler: @escaping CacheRefreshHandler) -> GrowthBookBuilder {
        self.refreshHandler = refreshHandler
        return self
    }

    /// Set Network Client - Network Client for Making API Calls
    /// - Parameter networkDispatcher: NetworkProtocol
    /// - Returns: GrowthBookBuilder
    @objc public func setNetworkDispatcher(networkDispatcher: NetworkProtocol) -> GrowthBookBuilder {
        self.networkDispatcher = networkDispatcher
        return self
    }
    
    /// Sets the service instance responsible for handling sticky bucketing operations.
    /// - Parameter stickyBucketService: StickyBucketServiceProtocol
    /// - Returns: GrowthBookBuilder
    @objc public func setCachingManager(cachingManager: CachingLayer) -> GrowthBookBuilder {
        self.cachingManager = cachingManager
        return self
    }
    
    @objc public func setStickyBucketService(stickyBucketService: StickyBucketServiceProtocol? = StickyBucketService()) -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = stickyBucketService
        return self
    }

    /// Set log level for SDK Logger. By default log level is set to `info`
    /// - Parameter level: LoggerLevel
    /// - Returns: GrowthBookBuilder
    @objc public func setLogLevel(_ level: LoggerLevel) -> GrowthBookBuilder {
        growthBookBuilderModel.logLevel = GBLogger.getLoggingLevel(from: level)
        return self
    }
    
    /// Forces specific experiments to use designated variations
    /// - Parameter forcedVariations: [String: Int]
    /// - Returns: GrowthBookBuilder
    @objc public func setForcedVariations(forcedVariations: [String: Int]) -> GrowthBookBuilder {
        growthBookBuilderModel.forcedVariations = JSON(forcedVariations)
        return self
    }
    /// If qaMode is true, experiments return immediately (not in experiment, variationId 0)
    /// - Parameter isEnabled: Bool
    /// - Returns: GrowthBookBuilder
    @objc public func setQAMode(isEnabled: Bool) -> GrowthBookBuilder {
        growthBookBuilderModel.isQaMode = isEnabled
        return self
    }

    /// If isEnabled is false, return immediately (not in experiment, variationId 0)
    /// - Parameter isEnabled: Bool
    /// - Returns: GrowthBookBuilder
    @objc public func setEnabled(isEnabled: Bool) -> GrowthBookBuilder {
        growthBookBuilderModel.isEnabled = isEnabled
        return self
    }
    
    /// Sets the system directory path used for system-level cache storage.
    /// - Parameter systemDirectory: CacheDirectory
    /// - Returns: GrowthBookBuilder
    @objc public func setSystemCacheDirectory(_ systemDirectory: CacheDirectory) -> GrowthBookBuilder {
        cachingManager.setSystemCacheDirectory(systemDirectory)
        return self
    }
    
    /// Sets the custom directory path for\ cache storage.
    /// - Parameter customDirectory: String
    /// - Returns: GrowthBookBuilder
    @objc public func setCustomCacheDirectory(_ customDirectory: String) -> GrowthBookBuilder {
        cachingManager.setCustomCachePath(customDirectory)
        return self
    }
    
    /// Initialize the SDK with all previously set parameters and methods.
    /// - Returns: GrowthBookSDK
    @objc public func setStreamingHost(streamingHost: String) -> GrowthBookBuilder {
        growthBookBuilderModel.streamingHost = streamingHost
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

        return GrowthBookSDK(contextManager: contextManager, refreshHandler: refreshHandler, logLevel: growthBookBuilderModel.logLevel, networkDispatcher: networkDispatcher, cachingManager: cachingManager, ttlSeconds: ttlSeconds)
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
    private var forcedFeatures: JSON = JSON()
    private var attributeOverrides: JSON = JSON()
    private var savedGroupsValues: JSON?
    private var evalContext: EvalContext? = nil
    private let evaluationLock = NSLock()
    private var ttlSeconds: Int
    var cachingManager: CachingLayer
    // Serial queue for thread-safe access to evalContext and gbContext.features
    private let syncQueue = DispatchQueue(label: "com.growthbook.sdk.sync", qos: .userInitiated)
    
    init(contextManager: ContextManager,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil,
         savedGroups: JSON? = nil,
         cachingManager: CachingLayer,
         ttlSeconds: Int) {
        self.contextManager = contextManager
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.savedGroupsValues = savedGroups
        self.cachingManager = cachingManager
        self.ttlSeconds = ttlSeconds
        super.init()
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        
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
        
        evaluationLock.lock()
            
        // Initialize evalContext from contextManager
        self.evalContext = contextManager.getEvalContext()
        
        evaluationLock.unlock()
        
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
                     cachingManager: CachingLayer,
                     ttlSeconds: Int
    ) {
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
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
    }
        
    /// Manually Refresh Cache
    @objc public func refreshCache() {
        let globalConfig = contextManager.getGlobalConfig()
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            if globalConfig.remoteEval {
                self.refreshForRemoteEval()
            } else {
                self.featureVM.fetchFeatures(apiUrl: contextManager.getFeaturesURL())
            }
        }
    }
    
    /// This function removes all files and subdirectories within the designated cache directory, which is a specific subdirectory within the app's cache directory.
    @objc public func clearCache() {
        cachingManager.clearCache()
    }

    /// Get Context - Holding the complete data regarding cached features & attributes etc.
    /// Note: This method is kept for backward compatibility but returns a Context created from ContextManager
    @objc public func getGBContext() -> Context {
        syncQueue.sync {
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
    }
    
    public func getGBAttributes() -> JSON {
        syncQueue.sync { contextManager.getEvaluationData().attributes }
    }
    
    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        syncQueue.sync { contextManager.getEvaluationData().features }
    }
    
    /// Subscribe to all experiment execution events.
    /// - Parameter result: ExperimentRunCallback
    @objc public func subscribe(_ result: @escaping ExperimentRunCallback) {
        self.subscriptions.append(result)
    }
    
    /// Remove all experiment callback functions.
    @objc public func clearSubscriptions() {
        self.subscriptions.removeAll()
    }

    /// Get the value of the feature with a fallback
    /// - Parameters:
    ///   - id: String
    ///   - defaultValue: JSON
    /// - Returns: JSON
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        syncQueue.sync {
            evaluationLock.lock()
            defer { evaluationLock.unlock() }
            let context = getEvalContext()
            let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
            // Update evalContext with any sticky bucket changes
            contextManager.syncFromEvaluation(context)
            return result.value ?? defaultValue
        }
    }

    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.contextManager.updateEvalData { data in
                data.features = features
                self.refreshStickyBucketService()
            }
            if isRemote {
                self.refreshHandler?(.none)
            }
        }
    }
    
    /// The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user
    /// - Parameters:
    ///   - encryptedString: String
    ///   - encryptionKey: String
    ///   - subtle: CryptoProtocol
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }
        
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.contextManager.updateEvalData { data in
                data.features = features
            }
            self.evalContext = self.contextManager.getEvalContext()
            self.refreshStickyBucketService()
        }
    }

    @objc public func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(.failedToFetchData)
        }
    }
    
    private func getEvalContext() -> EvalContext {
        contextManager.getEvalContext()
    }
    
    @objc public func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        refreshHandler?(.failedToFetchData)
    }

    public func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.contextManager.updateEvalData { data in
                data.savedGroups = savedGroups
            }
            self.refreshHandler?(.none)
        }
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
    /// - Parameter id: String
    /// - Returns: FeatureResult
    @objc public func evalFeature(id: String) -> FeatureResult {
        syncQueue.sync {
            let context = getEvalContext()
            let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
            // Update evalContext with any sticky bucket changes
            contextManager.syncFromEvaluation(context)
            return result
        }
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    /// - Parameter id: String
    /// - Returns: Bool
    @objc public func isOn(feature id: String) -> Bool {
        syncQueue.sync { evalFeature(id: id).isOn }
    }

    /// The run method takes an Experiment object and returns an experiment result
    /// - Parameter experiment: Experiment
    /// - Returns: ExperimentResult
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        return syncQueue.sync {
            let context = getEvalContext()
            let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: experiment)
            // Update evalContext with any sticky bucket changes
            contextManager.syncFromEvaluation(context)
            
            self.subscriptions.forEach { subscription in
                subscription(experiment, result)
            }
            
            return result
        }
    }
    
    /// The setForcedFeatures method updates forced features
    /// - Parameter forcedFeatures: Any
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.contextManager.updateEvalData { data in
                data.forcedFeatureValues = JSON(forcedFeatures)
            }
            self.refreshForRemoteEval()
        }
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    /// - Parameter attributes: Any
    @objc public func setAttributes(attributes: Any) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.contextManager.updateEvalData { data in
                data.attributes = JSON(attributes)
            }
            self.refreshStickyBucketService()
        }
    }
    
    /// Merges the provided user attributes with the existing ones.
    /// - Throws: `SwiftyJSON.Error.wrongType` if the top-level JSON types differ
    @objc public func appendAttributes(attributes: Any) throws {
        try syncQueue.sync {
            let evalData = contextManager.getEvaluationData()
            let updatedAttributes = try evalData.attributes.merged(with: JSON(attributes))
            contextManager.updateEvalData { data in
                data.attributes = updatedAttributes
            }
            refreshStickyBucketService()
        }
    }
    
    /// Sets custom attribute values that override the default ones
    /// - Parameter overrides: Ant
    @objc public func setAttributeOverrides(overrides: Any) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.attributeOverrides = JSON(overrides)
            let globalConfig = self.contextManager.getGlobalConfig()
            if globalConfig.stickyBucketService != nil {
                self.refreshStickyBucketService()
            }
            self.refreshForRemoteEval()
        }
    }
    
    /// The setForcedVariations method updates forced variations and makes API call if remote eval is enabled
    /// - Parameter forcedVariations: Any
    @objc public func setForcedVariations(forcedVariations: Any) {
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            self.contextManager.updateEvalData { data in
                data.forcedVariations = JSON(forcedVariations)
            }
            self.refreshForRemoteEval()
        }
    }
    
    /// Updates API request headers for dynamic header management
    /// - Parameter headers: [String: String]
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
        syncQueue.async { [weak self] in
            guard let self = self else { return }
            let context = getEvalContext()
            let globalConfig = contextManager.getGlobalConfig()
            if globalConfig.stickyBucketService != nil {
                let evalData = contextManager.getEvaluationData()
                Utils.refreshStickyBuckets(context: context, attributes: evalData.attributes, data: data)
            }
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
