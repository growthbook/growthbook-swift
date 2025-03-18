import Foundation

/// GrowthBookBuilder - Root Class for SDK Initializers for GrowthBook SDK
protocol GrowthBookProtocol: AnyObject {
    var growthBookBuilderModel: GrowthBookModel { get set }

    func setForcedVariations(forcedVariations: [String: Int]) -> GrowthBookBuilder
    func setQAMode(isEnabled: Bool) -> GrowthBookBuilder
    func setEnabled(isEnabled: Bool) -> GrowthBookBuilder
    func initializer() -> GrowthBookSDK
}

public struct GrowthBookModel: Sendable {
    public var instance: GrowthBookInstance
    public var features: Data?
    public var attributes: JSON
    public var trackingClosure: TrackingCallback
    public var logLevel: Level = .info
    public var isQaMode: Bool = false
    public var isEnabled: Bool = true
    public var forcedVariations: JSON?
    public var stickyBucketService: StickyBucketServiceProtocol?

    public init(
        instance: GrowthBookInstance,
        features: Data? = nil,
        attributes: JSON,
        trackingClosure: @escaping TrackingCallback,
        logLevel: Level = .info,
        isQaMode: Bool = false,
        isEnabled: Bool = true,
        forcedVariations: JSON? = nil,
        stickyBucketService: StickyBucketServiceProtocol? = nil
    )
    {
        self.instance = instance
        self.features = features
        self.attributes = attributes
        self.trackingClosure = trackingClosure
        self.logLevel = logLevel
        self.isQaMode = isQaMode
        self.isEnabled = isEnabled
        self.forcedVariations = forcedVariations
        self.stickyBucketService = stickyBucketService
    }
}

public struct GrowthBookCacheOptions: Sendable, Equatable {
    public let directoryURL: URL
    public let featureCacheFilename: String
    public let savedGroupsCacheFilename: String

    public init(directoryURL: URL, featureCacheFilename: String, savedGroupsCacheFilename: String) {
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

    public func settingDirectoryURL(_ directoryURL: URL) -> Self {
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

    private var featuresFetchResultHandler: FeaturesFetchResultHandler?
    private var networkDispatcher: GrowthBookNetworkProtocol = GrowthBookNetworkClient()
    private var cacheOptions: GrowthBookCacheOptions = .init(cacheDirectory: .applicationSupport, featureCacheFilename: "\(Constants.featureCache).txt", savedGroupsCacheFilename: "\(Constants.savedGroupsCache).txt")

    public init(
        growthBookBuilderModel: GrowthBookModel,
        featuresFetchResultHandler: FeaturesFetchResultHandler? = nil,
        networkDispatcher: GrowthBookNetworkProtocol = GrowthBookNetworkClient(),
        cacheOptions: GrowthBookCacheOptions
    )
    {
        self.growthBookBuilderModel = growthBookBuilderModel
        self.featuresFetchResultHandler = featuresFetchResultHandler
        self.networkDispatcher = networkDispatcher
        self.cacheOptions = cacheOptions
    }
//    public init(apiHost: String? = nil, clientKey: String? = nil, encryptionKey: String? = nil, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, featuresFetchResultHandler: FeaturesFetchResultHandler? = nil, backgroundSync: Bool = false, remoteEval: Bool = false) {
//        growthBookBuilderModel = GrowthBookModel(apiHost: apiHost, clientKey: clientKey, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
//        self.featuresFetchResultHandler = featuresFetchResultHandler
//    }
//
//    public init(features: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, featuresFetchResultHandler: FeaturesFetchResultHandler? = nil, backgroundSync: Bool, remoteEval: Bool = false) {
//        growthBookBuilderModel = GrowthBookModel(features: features, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
//        self.featuresFetchResultHandler = featuresFetchResultHandler
//    }
//
//    init(apiHost: String, clientKey: String, encryptionKey: String? = nil, attributes: JSON, trackingCallback: @escaping TrackingCallback, featuresFetchResultHandler: FeaturesFetchResultHandler?, backgroundSync: Bool, remoteEval: Bool = false) {
//        growthBookBuilderModel = GrowthBookModel(apiHost: apiHost, clientKey: clientKey, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback, backgroundSync: backgroundSync, remoteEval: remoteEval)
//        self.featuresFetchResultHandler = featuresFetchResultHandler
//    }

    /// Set Refresh Handler - Will be called when cache is refreshed
    public func setRefreshHandler(featuresFetchResultHandler: @escaping FeaturesFetchResultHandler) -> GrowthBookBuilder {
        self.featuresFetchResultHandler = featuresFetchResultHandler
        return self
    }

    /// Set Network Client - Network Client for Making API Calls
    public func setNetworkDispatcher(networkDispatcher: GrowthBookNetworkProtocol) -> GrowthBookBuilder {
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
//        if let clientKey = growthBookBuilderModel.instance.clientKey {
            let hashedClientKey: String = CachingManager.keyHash(growthBookBuilderModel.instance.clientKey)
            cacheDirectorySuffix = "-\(hashedClientKey)"
//        } else {
//            cacheDirectorySuffix = ""
//        }

        let directoryURL: URL = directory.url.appendingPathComponent("GrowthBook-Cache\(cacheDirectorySuffix)", isDirectory: true)

        return setCacheDirectoryURL(directoryURL)
    }

    @objc public func setCacheDirectoryURL(_ directoryURL: URL) -> GrowthBookBuilder {
        self.cacheOptions = cacheOptions.settingDirectoryURL(directoryURL)
        growthBookBuilderModel.stickyBucketService?.updateCacheDirectoryURL(directoryURL)
        return self
    }

    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            isEnabled: growthBookBuilderModel.isEnabled,
            attributes: growthBookBuilderModel.attributes,
            forcedVariations: growthBookBuilderModel.forcedVariations,
            stickyBucketService: growthBookBuilderModel.stickyBucketService,
            isQaMode: growthBookBuilderModel.isQaMode,
            trackingClosure: growthBookBuilderModel.trackingClosure
        )

        let hashedClientKey: String = CachingManager.keyHash(growthBookBuilderModel.instance.clientKey)
        let cacheDirectoryURL = cacheOptions.directoryURL
            .appendingPathComponent("\(hashedClientKey)")

        if let stickyBucketService = growthBookBuilderModel.stickyBucketService {
            stickyBucketService.updateCacheDirectoryURL(
                cacheDirectoryURL.appendingPathComponent("sticky_bucket", isDirectory: true)
            )
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

        let instance: GrowthBookInstance = .init(
            apiHostURL: growthBookBuilderModel.instance.apiHostURL,
            clientKey: growthBookBuilderModel.instance.clientKey,
            payloadType: growthBookBuilderModel.instance.payloadType,
            refreshPolicy: growthBookBuilderModel.instance.refreshPolicy
        )

        return GrowthBookSDK(instance: instance, context: gbContext, featuresFetchResultHandler: featuresFetchResultHandler, logLevel: growthBookBuilderModel.logLevel, networkDispatcher: networkDispatcher, cachingManager: cachingManager)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject {
    private let featuresFetchResultHandler: FeaturesFetchResultHandler?
    private var subscriptions: [ExperimentRunCallback] = []
    public let gbContext: Context
    private var featureVM: FeaturesViewModel!
    private var forcedFeatures: JSON = JSON()
    private var attributeOverrides: JSON = JSON()
    private var evalContext: EvalContext? = nil
    private let cachingManager: GrowthBookSDKCachingManagerInterface

    init(
        instance: GrowthBookInstance,
        context: Context,
        featuresFetchResultHandler: FeaturesFetchResultHandler? = nil,
        logLevel: Level = .info,
        networkDispatcher: GrowthBookNetworkProtocol = GrowthBookNetworkClient(),
        features: Features? = nil,
        savedGroups: JSON? = nil,
        cachingManager: GrowthBookSDKCachingManagerInterface
    )
    {
        logger.minLevel = logLevel

        gbContext = context
        self.featuresFetchResultHandler = featuresFetchResultHandler
        self.cachingManager = cachingManager

        if let features {
            try? cachingManager.featuresCache.updateFeatures(features)
        }
        if let savedGroups {
            try? cachingManager.savedGroupsCache.updateSavedGroups(savedGroups)
        }

        super.init()

        let crypto: CryptoProtocol = Crypto()
        let featuresResponseDecryptor: FeaturesResponseDecryptorInterface = FeaturesResponseDecryptor(
            payloadType: instance.payloadType,
            crypto: crypto
        )
        let featuresDataParser: FeaturesDataParserInterface = FeaturesDataParser(
            featuresResponseDecryptor: featuresResponseDecryptor,
            decoder: JSONDecoder()
        )

        let remoteEvaluationParameters = RemoteEvalParams(attributes: gbContext.attributes, forcedFeatures: self.forcedFeatures, forcedVariations: gbContext.forcedVariations )

        let featuresModelFetcher: FeaturesModelFetcherInterface = FeaturesModelFetcher(
            payloadType: instance.payloadType,
            featuresURL: instance.featuresURL,
            remoteEvaluatedFeaturesURL: instance.remoteEvalURL,
            remoteEvaluationParameters: remoteEvaluationParameters,
            networkDispatcher: networkDispatcher,
            featuresDataParser: featuresDataParser
        )

        let featuresModelProvider: FeaturesModelProviderInterface? = FeaturesModelProviderBuilder.build(
            refreshPolicy: instance.refreshPolicy,
            serverSideEventsURL: instance.serverSideEventsURL,
            featuresDataParser: featuresDataParser,
            featuresModelFetcher: featuresModelFetcher
        )

        if let features = features {
            gbContext.features = features
        }

        self.featureVM = FeaturesViewModel(
            delegate: self,
            featuresCache: cachingManager.featuresCache,
            savedGroupsCache: cachingManager.savedGroupsCache,
            featuresModelProvider: featuresModelProvider,
            featuresModelFetcher: featuresModelFetcher
        )

        if let savedGroups {
            context.savedGroups = savedGroups
        }
        self.evalContext = Utils.initializeEvalContext(context: context)


        // Logger setup. if we have logHandler we have to re-initialise logger

        refreshStickyBucketService()
    }

    /// Manually Refresh Cache
    @objc public func refreshCache() {
        featureVM.fetchFeaturesOnce()
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
        updateEvaluationContext(with: gbContext)
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

    func featuresAPIModelSuccessfully(model: DecryptedFeaturesDataModel) {
        refreshStickyBucketService(model)
    }

    private func refreshStickyBucketService(_ data: DecryptedFeaturesDataModel? = nil) {
        if (gbContext.stickyBucketService != nil) {
            let evalContext = self.evalContext
            Utils.refreshStickyBuckets(context: evalContext!, attributes: evalContext!.userContext.attributes, data: data)
            gbContext.stickyBucketAssignmentDocs = evalContext?.options.stickyBucketAssignmentDocs
        }
    }

    func refreshForRemoteEval() {
        featureVM.fetchFeaturesOnce()
    }
}

extension GrowthBookSDK: FeaturesFlowDelegate {
    private func updateEvaluationContext(with newContext: Context) {
        self.evalContext = Utils.initializeEvalContext(context: newContext)
    }

    func featuresAPIModelSuccessfully(model: DecryptedFeaturesDataModel, fetchType: GrowthBookFeaturesFetchResult.FetchType) {
        gbContext.features = model.features
        gbContext.savedGroups = model.savedGroups

        updateEvaluationContext(with: gbContext)

        refreshStickyBucketService(model)
        
        featuresFetchResultHandler?(.init(type: fetchType, error: nil))
    }
    
    func featuresFetchFailed(error: any Error, fetchType: GrowthBookFeaturesFetchResult.FetchType) {
        featuresFetchResultHandler?(.init(type: fetchType, error: error))
    }
}
