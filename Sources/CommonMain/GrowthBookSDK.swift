import Foundation

/// GrowthBookBuilder - Root Class for SDK Initializers for GrowthBook SDK
protocol GrowthBookProtocol: AnyObject {
    var growthBookBuilderModel: GrowthBookModel { get set }

    func setForcedVariations(forcedVariations: [String: Int]) -> GrowthBookBuilder
    func setQAMode(isEnabled: Bool) -> GrowthBookBuilder
    func setEnabled(isEnabled: Bool) -> GrowthBookBuilder
    func initializer() -> GrowthBookSDK
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

    @nonobjc public init(
        growthBookBuilderModel: GrowthBookModel,
        networkDispatcher: NetworkProtocol,
        ttlSeconds: Int = 60,
        cachingManager: CachingLayer,
        refreshHandler: CacheRefreshHandler? = nil) {

        self.growthBookBuilderModel = growthBookBuilderModel
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.cachingManager = cachingManager
        self.ttlSeconds = ttlSeconds

        super.init()
    }

    @nonobjc public convenience init(
        growthBookBuilderModel: GrowthBookModel,
        apiRequestHeaders: [String: String] = [:],
        streamingHostRequestHeaders: [String: String] = [:],
        ttlSeconds: Int = 60,
        refreshHandler: CacheRefreshHandler? = nil,
        cachingManager: CachingLayer) {

        let networkDispatcher = CoreNetworkClient(
            apiRequestHeaders: apiRequestHeaders,
            streamingHostRequestHeaders: streamingHostRequestHeaders
        )
        self.init(
            growthBookBuilderModel: growthBookBuilderModel,
            networkDispatcher: networkDispatcher,
            ttlSeconds: ttlSeconds,
            cachingManager: cachingManager,
            refreshHandler: refreshHandler
        )
    }

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

    /// When true, features fetched remotely are cached but not applied to the running SDK.
    /// The updated payload is picked up automatically on next SDK initialization (app restart).
    ///
    /// - Note: When used together with `backgroundSync: true`, the SSE stream stays open and
    ///   keeps the on-disk cache warm for the next session. This is correct behaviour, but it
    ///   maintains an open connection whose sole effect during the current session is writing
    ///   to disk. Only enable backgroundSync alongside stableSession if you explicitly need
    ///   the cache to stay fresh between cold starts.
    /// - Parameter value: Bool
    /// - Returns: GrowthBookBuilder
    @objc public func setStableSession(_ value: Bool) -> GrowthBookBuilder {
        growthBookBuilderModel.stableSession = value
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
            stableSession: growthBookBuilderModel.stableSession,
            remoteEval: growthBookBuilderModel.remoteEval,
            trackingClosure: growthBookBuilderModel.trackingClosure,
            stickyBucketService: growthBookBuilderModel.stickyBucketService
        )

        // TODO: extract parsePreloadedFeatures() and resolveInitialFeatures() helpers to
        // reduce the length of initializer() — tracked for a follow-up refactoring PR.

        // Parse features from Data if available.
        // hasPreloadedPayload is set to true only on successful parse — an
        // unrecognised or corrupted payload must not suppress the fallback network fetch.
        var initialFeatures: Features = [:]
        var hasPreloadedPayload = false

        if let featuresData = growthBookBuilderModel.features {
            let decoder = JSONDecoder()
            // Try to decode as FeaturesDataModel first (API format)
            if let featuresModel = try? decoder.decode(FeaturesDataModel.self, from: featuresData) {
                if let features = featuresModel.features {
                    initialFeatures = features
                    hasPreloadedPayload = true
                } else if let encryptedString = featuresModel.encryptedFeatures,
                          let encryptionKey = growthBookBuilderModel.encryptionKey,
                          !encryptionKey.isEmpty {
                    // Preloaded payload uses encryptedFeatures — decrypt inline so
                    // the SDK can serve features immediately without a network round-trip.
                    let crypto = Crypto()
                    if let features = crypto.getFeaturesFromEncryptedFeatures(
                        encryptedString: encryptedString,
                        encryptionKey: encryptionKey
                    ) {
                        initialFeatures = features
                        hasPreloadedPayload = true
                    }
                    // decrypt failed → hasPreloadedPayload stays false → fallback fetch fires
                }
            } else if let features = try? decoder.decode(Features.self, from: featuresData) {
                // Fallback: try to decode directly as Features dictionary
                initialFeatures = features
                hasPreloadedPayload = true
            }
            // All decode attempts failed → hasPreloadedPayload stays false → fallback fetch fires
        }

        // In stableSession mode, an empty parsed payload is an invalid config — the session
        // would be locked with no features. Log a warning and fall back to the normal
        // cache/network fetch path so the session gets properly established.
        if globalConfig.stableSession && hasPreloadedPayload && initialFeatures.isEmpty {
            logger.warning("stableSession is enabled but the provided features payload parsed to an empty set. " +
                           "The SDK will operate without features until the first network fetch completes. " +
                           "Falling back to network fetch.")
            hasPreloadedPayload = false
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

        // Write the *parsed* features (Features dict format) to cache, not the raw API
        // envelope. fetchCachedFeatures() decodes the cache as Features ([String: Feature]),
        // so writing the raw FeaturesDataModel envelope would produce junk on decode and
        // silently overwrite the live feature set the next time refreshCache() is called.
        // Note: when hasPreloadedPayload was reset to false above (stableSession + empty payload),
        // this block is intentionally skipped. The fallback network fetch will write to cache
        // on its first successful response.
        if hasPreloadedPayload && !initialFeatures.isEmpty,
           let featureData = try? JSONEncoder().encode(initialFeatures) {
            cachingManager.saveContent(fileName: Constants.featureCache, content: featureData)
        }

        // Pass the parsed features when the caller supplied a valid, non-empty payload,
        // so GrowthBookSDK.init() skips the automatic refreshCache() call.
        // nil means "no payload provided (or invalid/empty) — fall back to cache/network."
        let preloadedFeatures: Features? = hasPreloadedPayload ? initialFeatures : nil
        return GrowthBookSDK(contextManager: contextManager, refreshHandler: refreshHandler, logLevel: growthBookBuilderModel.logLevel, networkDispatcher: networkDispatcher, features: preloadedFeatures, cachingManager: cachingManager, ttlSeconds: ttlSeconds)
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
    private var ttlSeconds: Int
    var cachingManager: CachingLayer

    private let lock = NSRecursiveLock()
    /// True once the session's initial features have been applied.
    /// Set once and never reset — used as the stableSession latch.
    private var sessionEstablished: Bool = false

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
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher), cachingManager: cachingManager, ttlSeconds: ttlSeconds, preloadedFeatures: features)

        let evalData = contextManager.getEvaluationData()
        let globalConfig = contextManager.getGlobalConfig()

        if let features = features {
            contextManager.updateEvalData { data in
                data.features = features
            }
            if globalConfig.stableSession {
                // Safe to set without withLock: the object has not yet escaped to other
                // threads at this point in init(), so no concurrent access is possible.
                sessionEstablished = true
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
        if let sseURL = contextManager.getSSEUrl(), globalConfig.backgroundSync {
            featureVM.connectBackgroundSync(sseUrl: sseURL)
        }

        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel

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

    private func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock.lock()
        defer { lock.unlock() }
        return try body()
    }

    /// Manually Refresh Cache
    @objc public func refreshCache() {
        withLock {
            let globalConfig = contextManager.getGlobalConfig()
            if globalConfig.remoteEval {
                refreshForRemoteEval()
            } else {
                featureVM.fetchFeatures(apiUrl: contextManager.getFeaturesURL())
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
        withLock {
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
        withLock { contextManager.getEvaluationData().attributes }
    }

    /// Get Cached Features
    @objc public func getFeatures() -> [String: Feature] {
        withLock { contextManager.getEvaluationData().features }
    }

    /// Subscribe to all experiment execution events.
    /// - Parameter result: ExperimentRunCallback
    @objc public func subscribe(_ result: @escaping ExperimentRunCallback) {
        withLock {
            self.subscriptions.append(result)
        }
    }

    /// Remove all experiment callback functions.
    @objc public func clearSubscriptions() {
        withLock {self.subscriptions.removeAll()}
    }

    /// Get the value of the feature with a fallback
    /// - Parameters:
    ///   - id: String
    ///   - defaultValue: JSON
    /// - Returns: JSON
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        withLock { _evalFeature(id: id).value ?? defaultValue }
    }

    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        withLock {
            let stableSession = contextManager.getGlobalConfig().stableSession

            // In stableSession mode, block every update once the session is established.
            // sessionEstablished is a one-way latch: set on the first apply (or at init when
            // a preloaded payload is provided) and never reset. Using a dedicated flag rather
            // than checking features.isEmpty is essential — an empty features response {} is
            // a valid server response that must also lock the session after it is applied.
            if stableSession && sessionEstablished {
                if isRemote {
                    logger.info("stableSession: new features received from network — cached for next session, not applied now")
                    self.refreshHandler?(.none)
                } else {
                    logger.debug("stableSession: ignoring cache refresh — session features already established")
                }
                return
            }

            self.contextManager.updateEvalData { data in
                data.features = features
            }
            self.refreshStickyBucketService()

            if stableSession {
                sessionEstablished = true
                logger.info("stableSession: initial features established. Session is now locked — subsequent refreshes will update the cache only and apply on next SDK initialization.")
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
    /// - Note: This method always writes directly to the session's feature set, even when
    ///   `stableSession` is enabled. It is an explicit, developer-initiated override — not
    ///   a background network or cache callback — and therefore bypasses the stableSession
    ///   guard intentionally. Do not call this mid-session if you need session stability.
    @objc public func setEncryptedFeatures(encryptedString: String, encryptionKey: String, subtle: CryptoProtocol? = nil) {
        let crypto: CryptoProtocol = subtle ?? Crypto()
        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }

        withLock {
            self.contextManager.updateEvalData { data in
                data.features = features
            }
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
        withLock {
            self.contextManager.updateEvalData { data in
                data.savedGroups = savedGroups
            }
            self.refreshHandler?(.none)
        }
    }

    /// If remote eval is enabled, send needed data to backend to proceed remote evaluation
    @objc public func refreshForRemoteEval() {
        withLock {
            let globalConfig = contextManager.getGlobalConfig()
            let evalData = contextManager.getEvaluationData()
            if !globalConfig.remoteEval { return }
            let forcedFeaturesArray = convertForcedFeaturesToArray(evalData.forcedFeatureValues)
            let forcedFeaturesJson = JSON(forcedFeaturesArray ?? [])

            let payload = RemoteEvalParams(attributes: evalData.attributes, forcedFeatures: forcedFeaturesJson, forcedVariations: evalData.forcedVariations)
            featureVM.fetchFeatures(apiUrl: contextManager.getRemoteEvalUrl(), remoteEval: globalConfig.remoteEval, payload: payload)
        }
    }

    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    /// - Parameter id: String
    /// - Returns: FeatureResult
    @objc public func evalFeature(id: String) -> FeatureResult {
        withLock { _evalFeature(id: id) }
    }

    private func _evalFeature(id: String) -> FeatureResult {
        let context = contextManager.getEvalContext()
        let result = FeatureEvaluator(context: context, featureKey: id).evaluateFeature()
        contextManager.syncFromEvaluation(context)
        return result
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    /// - Parameter id: String
    /// - Returns: Bool
    @objc public func isOn(feature id: String) -> Bool {
        withLock { _evalFeature(id: id).isOn }
    }

    /// The run method takes an Experiment object and returns an experiment result
    /// - Parameter experiment: Experiment
    /// - Returns: ExperimentResult
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        withLock {
            let result = _runExperiment(experiment: experiment)
            self.subscriptions.forEach { $0(experiment, result) }
            return result
        }
    }

    private func _runExperiment(experiment: Experiment) -> ExperimentResult {
        let context = contextManager.getEvalContext()
        let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: experiment)
        contextManager.syncFromEvaluation(context)
        return result
    }


    /// The setForcedFeatures method updates forced features
    /// - Parameter forcedFeatures: Any
    @objc public func setForcedFeatures(forcedFeatures: Any) {
        withLock {
            self.contextManager.updateEvalData { data in
                data.forcedFeatureValues = JSON(forcedFeatures)
            }
            self.refreshForRemoteEval()
        }
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    /// - Parameter attributes: Any
    @objc public func setAttributes(attributes: Any) {
        withLock {
            self.contextManager.updateEvalData { data in
                data.attributes = JSON(attributes)
            }
            self.refreshStickyBucketService()
        }
    }

    /// Merges the provided user attributes with the existing ones.
    /// - Throws: `SwiftyJSON.Error.wrongType` if the top-level JSON types differ
    @objc public func appendAttributes(attributes: Any) throws {
        try withLock {
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
        withLock {
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
        withLock {
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
        withLock {
            refreshStickyBucketService(model)
        }
    }

    @objc private func refreshStickyBucketService(_ data: FeaturesDataModel? = nil) {
        let globalConfig = contextManager.getGlobalConfig()
        guard let service = globalConfig.stickyBucketService else { return }

        let evalData = contextManager.getEvaluationData()
        let context = contextManager.getEvalContext()


        Utils.refreshStickyBuckets(
            stickyBucketService: service,
            context: context,
            attributes: evalData.attributes,
            data: data
        ) { [weak self] docs in
            guard let self = self else { return }
            self.withLock {
                self.contextManager.updateEvalData { data in
                    data.stickyBucketAssignmentDocs = docs
                }
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
