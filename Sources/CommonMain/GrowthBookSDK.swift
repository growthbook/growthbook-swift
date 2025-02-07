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
    var clientKey: String?
    var encryptionKey: String?
    var features: Data?
    var attributes: JSON
    var trackingClosure: TrackingCallback
    var logLevel: Level = .info
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON?
    var stickyBucketService: StickyBucketServiceProtocol?
    var backgroundSync: Bool
    var remoteEval: Bool
}

struct GrowthBookCacheOptions {
    let directoryURL: URL
    let featureCacheFilename: String
    let savedGroupsCacheFilename: String

    init(directoryURL: URL, featureCacheFilename: String, savedGroupsCacheFilename: String) {
        self.directoryURL = directoryURL
        self.featureCacheFilename = featureCacheFilename
        self.savedGroupsCacheFilename = savedGroupsCacheFilename
    }

    init(cacheDirectory: CacheDirectory, featureCacheFilename: String, savedGroupsCacheFilename: String) {
        self.init(
            directoryURL: cacheDirectory.url,
            featureCacheFilename: featureCacheFilename,
            savedGroupsCacheFilename: savedGroupsCacheFilename
        )
    }

    func settingDirectoryURL(_ directoryURL: URL) -> Self {
        .init(
            directoryURL: directoryURL,
            featureCacheFilename: featureCacheFilename,
            savedGroupsCacheFilename: savedGroupsCacheFilename
        )
    }
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
    private var cacheOptions: GrowthBookCacheOptions = .init(cacheDirectory: .applicationSupport, featureCacheFilename: "\(Constants.featureCache).txt", savedGroupsCacheFilename: "\(Constants.savedGroupsCache).txt")

    @objc public init(apiHost: String? = nil, clientKey: String? = nil, encryptionKey: String? = nil, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil, backgroundSync: Bool = false, remoteEval: Bool = false) {
        growthBookBuilderModel = GrowthBookModel(apiHost: apiHost, clientKey: clientKey, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
        self.refreshHandler = refreshHandler
    }

    @objc public init(features: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil, backgroundSync: Bool, remoteEval: Bool = false) {
        growthBookBuilderModel = GrowthBookModel(features: features, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
        self.refreshHandler = refreshHandler
    }

    init(apiHost: String, clientKey: String, encryptionKey: String? = nil, attributes: JSON, trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?, backgroundSync: Bool, remoteEval: Bool = false) {
        growthBookBuilderModel = GrowthBookModel(apiHost: apiHost, clientKey: clientKey, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
        self.refreshHandler = refreshHandler
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

    public func setStickyBucketService(stickyBucketService: StickyBucketServiceProtocol? = StickyBucketService(cache: .none)) -> GrowthBookBuilder {
        growthBookBuilderModel.stickyBucketService = stickyBucketService
        return self
    }

    /// Set log level for SDK Logger
    ///
    /// By default log level is set to `info`
    @objc public func setLogLevel(_ level: LoggerLevel) -> GrowthBookBuilder {
        growthBookBuilderModel.logLevel = Logger.getLoggingLevel(from: level)
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

    @available(*, deprecated, renamed: "setCacheDirectoryURL", message: "Use setCacheDirectoryURL instead")
    public func setCacheDirectory(_ directory: CacheDirectory) -> GrowthBookBuilder {
        let cacheDirectorySuffix: String
        if let clientKey = growthBookBuilderModel.clientKey {
            let hashedClientKey: String = CachingManager.keyHash(clientKey)
            cacheDirectorySuffix = "-hashedClientKey"
        } else {
            cacheDirectorySuffix = ""
        }

        let directoryURL: URL = directory.url.appendingPathComponent("GrowthBook-Cache\(cacheDirectorySuffix)", isDirectory: true)

        return setCacheDirectoryURL(directoryURL)
    }

    @objc public func setCacheDirectoryURL(_ directoryURL: URL) -> GrowthBookBuilder {
        cacheOptions = cacheOptions.settingDirectoryURL(directoryURL)
        (growthBookBuilderModel.stickyBucketService as? StickyBucketFileStorageCacheInterface)?.updateCacheDirectoryURL(directoryURL)
        return self
    }

    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            apiHost: growthBookBuilderModel.apiHost,
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
        

        let cacheDirectoryURL: URL
        if let clientKey = growthBookBuilderModel.clientKey {
            let lastPathComponent: String = cacheOptions.directoryURL.lastPathComponent
            let hashedClientKey: String = CachingManager.keyHash(clientKey)
            cacheDirectoryURL = cacheOptions.directoryURL
                .deletingLastPathComponent()
                .appendingPathComponent("\(lastPathComponent)-\(hashedClientKey)")
        } else {
            cacheDirectoryURL = cacheOptions.directoryURL
        }

        let cachingManager: GrowthBookSDKCachingManagerInterface = GrowthBookSDKCachingManager.withFileStorage(
            directoryURL: cacheDirectoryURL,
            featuresCacheFilename: cacheOptions.featureCacheFilename,
            savedGroupsCacheFilename: cacheOptions.savedGroupsCacheFilename,
            fileManager: .default
        )

        if let features = growthBookBuilderModel.features {
            try? cachingManager.featuresCache.setEncodedFeaturesRawData(features)
        }

        return GrowthBookSDK(context: gbContext, refreshHandler: refreshHandler, networkDispatcher: networkDispatcher, cachingManager: cachingManager)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject, FeaturesFlowDelegate {
    private var refreshHandler: CacheRefreshHandler?
    private var subscriptions: [ExperimentRunCallback] = []
    private var networkDispatcher: NetworkProtocol
    public var gbContext: Context
    private var featureVM: FeaturesViewModel!
    private var forcedFeatures: JSON = JSON()
    private var attributeOverrides: JSON = JSON()
    private var savedGroupsValues: JSON?
    private var evalContext: EvalContext? = nil
    private var cachingManager: GrowthBookSDKCachingManagerInterface

    init(context: Context,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil,
         savedGroups: JSON? = nil,
         cachingManager: GrowthBookSDKCachingManagerInterface) {
        gbContext = context
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.savedGroupsValues = savedGroups
        self.cachingManager = cachingManager
        super.init()
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher), featuresCache: cachingManager.featuresCache, savedGroupsCache: cachingManager.savedGroupsCache)
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
        try? cachingManager.clearCache()
        try? gbContext.stickyBucketService?.clearCache()
        CachingManager.shared.clearCache()
    }

    /// Get Context - Holding the complete data regarding cached features & attributes etc.
    @objc public func getGBContext() -> Context {
        return gbContext
    }

    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        return gbContext.features
    }

    public func subscribe(_ result: @escaping ExperimentRunCallback) {
        self.subscriptions.append(result)
    }

    public func clearSubscriptions() {
        self.subscriptions.removeAll()
    }

    /// Get the value of the feature with a fallback
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        return FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: id).evaluateFeature().value ?? defaultValue
    }

    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        gbContext.features = features
        if isRemote {
            refreshHandler?(true)
        }
    }

    /// The setEncryptedFeatures method takes an encrypted string with an encryption key and then decrypts it with the default method of decrypting or with a method of decrypting from the user
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }

        gbContext.features = features
    }

    @objc public func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(false)
        }
    }

    public func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        refreshHandler?(false)
    }

    public func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        gbContext.savedGroups = savedGroups
        refreshHandler?(true)
    }

    /// If remote eval is enabled, send needed data to backend to proceed remote evaluation
    @objc public func refreshForRemoteEval() {
        if !gbContext.remoteEval { return }
        let payload = RemoteEvalParams(attributes: gbContext.attributes, forcedFeatures: self.forcedFeatures, forcedVariations: gbContext.forcedVariations )
        featureVM.fetchFeatures(apiUrl: gbContext.getRemoteEvalUrl(), remoteEval: gbContext.remoteEval, payload: payload)
    }

    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    @objc public func evalFeature(id: String) -> FeatureResult {
        return FeatureEvaluator(context: Utils.initializeEvalContext(context: gbContext), featureKey: id).evaluateFeature()
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    @objc public func isOn(feature id: String) -> Bool {
        return evalFeature(id: id).isOn
    }

    /// The run method takes an Experiment object and returns an experiment result
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        let result = ExperimentEvaluator().evaluateExperiment(context: Utils.initializeEvalContext(context: gbContext), experiment: experiment)

        self.subscriptions.forEach { subscription in
            subscription(experiment, result)
        }

        return result
    }

    /// The setForcedFeatures method updates forced features
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        self.forcedFeatures = JSON(forcedFeatures)
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    @objc public func setAttributes(attributes: Any) {
        gbContext.attributes = JSON(attributes)
        refreshStickyBucketService()
    }

    @objc public func setAttributeOverrides(overrides: Any) {
        attributeOverrides = JSON(overrides)
        if gbContext.stickyBucketService != nil {
            refreshStickyBucketService()
        }
        refreshForRemoteEval()
    }

    /// The setForcedVariations method updates forced variations and makes API call if remote eval is enabled
    @objc public func setForcedVariations(forcedVariations: Any) {
        gbContext.forcedVariations = JSON(forcedVariations)
        refreshForRemoteEval()
    }

    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {
        refreshStickyBucketService(model)
    }

    private func refreshStickyBucketService(_ data: FeaturesDataModel? = nil) {
        if (gbContext.stickyBucketService != nil) {
            Utils.refreshStickyBuckets(context: evalContext!, attributes: evalContext!.userContext.attributes, data: data)
        }
    }
}
