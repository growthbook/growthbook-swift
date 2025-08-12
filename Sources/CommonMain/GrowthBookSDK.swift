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

    @objc public init(features: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil, backgroundSync: Bool, remoteEval: Bool = false, apiRequestHeaders: [String: String]? = nil, streamingHostRequestHeaders: [String: String]? = nil) {
        growthBookBuilderModel = GrowthBookModel(features: features, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval, apiRequestHeaders: apiRequestHeaders, streamingHostRequestHeaders: streamingHostRequestHeaders)
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
                apiRequestHeaders: apiRequestHeaders ?? [:],
                streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
            )
        self.cachingManager = CachingManager()
    }

    init(apiHost: String, clientKey: String, encryptionKey: String? = nil, attributes: JSON, trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?, backgroundSync: Bool, remoteEval: Bool = false, apiRequestHeaders: [String: String]? = nil, streamingHostRequestHeaders: [String: String]? = nil) {
        growthBookBuilderModel = GrowthBookModel(apiHost: apiHost, clientKey: clientKey, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval, apiRequestHeaders: apiRequestHeaders, streamingHostRequestHeaders: streamingHostRequestHeaders)
        self.refreshHandler = refreshHandler
        self.networkDispatcher = CoreNetworkClient(
                apiRequestHeaders: apiRequestHeaders ?? [:],
                streamingHostRequestHeaders: streamingHostRequestHeaders ?? [:]
            )
        self.cachingManager = CachingManager(apiKey: clientKey)
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
    @objc public func setStickyBucketService(stickyBucketService: StickyBucketServiceProtocol? = StickyBucketService()) -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = stickyBucketService
        return self
    }
    
    /// Set log level for SDK Logger. By default log level is set to `info`
    /// - Parameter level: LoggerLevel
    /// - Returns: GrowthBookBuilder
    @objc public func setLogLevel(_ level: LoggerLevel) -> GrowthBookBuilder {
        growthBookBuilderModel.logLevel = Logger.getLoggingLevel(from: level)
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
            remoteEval: growthBookBuilderModel.remoteEval
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
    /// GrowthBook context
    public var gbContext: Context
    private var subscriptions: [ExperimentRunCallback] = []
    private var networkDispatcher: NetworkProtocol
    private var featureVM: FeaturesViewModel!
    private var forcedFeatures: JSON = JSON()
    private var attributeOverrides: JSON = JSON()
    private var savedGroupsValues: JSON?
    private var evalContext: EvalContext? = nil
    var refreshHandler: CacheRefreshHandler?
    var cachingManager: CachingManager

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
        self.evalContext = Utils.initializeEvalContext(context: context)
                
        // if the SSE URL is available and background sync variable is set to true, then we have to connect to SSE Server
        if let sseURL = context.getSSEUrl(), context.backgroundSync {
            featureVM.connectBackgroundSync(sseUrl: sseURL)
        }
        
        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel
        
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
    /// - Returns: Context
    @objc public func getGBContext() -> Context {
        return gbContext
    }

    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        return gbContext.features
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
    
    /// Get attribute overrides of your specific user
    /// - Returns: JSON
    public func getAttributeOverrides() -> JSON {
        return attributeOverrides
    }

    /// Get the value of the feature with a fallback
    /// - Parameters:
    ///   - id: String
    ///   - defaultValue: JSON
    /// - Returns: JSON
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        return FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: id).evaluateFeature().value ?? defaultValue
    }
    
    /// The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user
    /// - Parameters:
    ///   - encryptedString: String
    ///   - encryptionKey: String
    ///   - subtle: CryptoProtocol
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }
        
        gbContext.features = features
    }
    
    /// If remote eval is enabled, send needed data to backend to proceed remote evaluation
    @objc public func refreshForRemoteEval() {
        if !gbContext.remoteEval { return }
        let payload = RemoteEvalParams(attributes: gbContext.attributes, forcedFeatures: self.forcedFeatures, forcedVariations: gbContext.forcedVariations )
        featureVM.fetchFeatures(apiUrl: gbContext.getRemoteEvalUrl(), remoteEval: gbContext.remoteEval, payload: payload)
    }

    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    /// - Parameter id: String
    /// - Returns: FeatureResult
    @objc public func evalFeature(id: String) -> FeatureResult {
        return FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: id).evaluateFeature()
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    /// - Parameter id: String
    /// - Returns: Bool
    @objc public func isOn(feature id: String) -> Bool {
        return evalFeature(id: id).isOn
    }

    /// The run method takes an Experiment object and returns an experiment result
    /// - Parameter experiment: Experiment
    /// - Returns: ExperimentResult
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        let result = ExperimentEvaluator().evaluateExperiment(context: Utils.initializeEvalContext(context: gbContext), experiment: experiment)
        
        self.subscriptions.forEach { subscription in
            subscription(experiment, result)
        }
        
        return result
    }
    
    /// The setForcedFeatures method updates forced features
    /// - Parameter forcedFeatures: Any
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        self.forcedFeatures = JSON(forcedFeatures)
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    /// - Parameter attributes: Any
    @objc public func setAttributes(attributes: Any) {
        gbContext.attributes = JSON(attributes)
        refreshStickyBucketService()
    }
    
    /// Sets custom attribute values that override the default ones
    /// - Parameter overrides: Any
    @objc public func setAttributeOverrides(overrides: Any) {
        attributeOverrides = JSON(overrides)
        if gbContext.stickyBucketService != nil {
            refreshStickyBucketService()
        }
        refreshForRemoteEval()
    }
    
    /// The setForcedVariations method updates forced variations and makes API call if remote eval is enabled
    /// - Parameter forcedVariations: Any
    @objc public func setForcedVariations(forcedVariations: Any) {
        gbContext.forcedVariations = JSON(forcedVariations)
        refreshForRemoteEval()
    }
    
    @objc func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        gbContext.features = features
        if isRemote {
            refreshHandler?(true)
        }
    }

    @objc func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(false)
        }
    }
    
    @objc func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        refreshHandler?(false)
    }

    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        gbContext.savedGroups = savedGroups
        refreshHandler?(true)
    }
    
    @objc func featuresAPIModelSuccessfully(model: FeaturesDataModel) {
        refreshStickyBucketService(model)
    }
    
    @objc private func refreshStickyBucketService(_ data: FeaturesDataModel? = nil) {
        if (gbContext.stickyBucketService != nil) {
            Utils.refreshStickyBuckets(context: evalContext!, attributes: evalContext!.userContext.attributes, data: data)
        }
    }
}
