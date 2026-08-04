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

    /// Registers a plugin that will receive experiment and feature evaluation events.
    /// - Parameter plugin: Any object conforming to `GrowthBookPlugin`.
    /// - Returns: GrowthBookBuilder
    public func addPlugin(_ plugin: GrowthBookPlugin) -> GrowthBookBuilder {
        growthBookBuilderModel.plugins.append(plugin)
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
            stickyBucketService: growthBookBuilderModel.stickyBucketService,
            plugins: growthBookBuilderModel.plugins
        )

        // TODO: extract parsePreloadedFeatures() and resolveInitialFeatures() helpers to
        // reduce the length of initializer() — tracked for a follow-up refactoring PR.

        // Parse features from Data if available.
        // hasPreloadedPayload is set to true only on successful parse — an
        // unrecognised or corrupted payload must not suppress the fallback network fetch.
        var initialFeatures: Features = [:]
        var hasPreloadedPayload = false
        // Contextual bandit definitions travel in the same envelope as the features. They are
        // applied independently of hasPreloadedPayload: a payload can legitimately carry bandits
        // while the features themselves come from cache or network.
        var initialContextualBandits: JSON? = nil

        if let featuresData = growthBookBuilderModel.features {
            let decoder = JSONDecoder()
            // Try to decode as FeaturesDataModel first (API format).
            // Guard requires at least one known envelope field to be non-nil: because every field on
            // FeaturesDataModel is Optional, the decoder accepts any JSON object and always succeeds,
            // so without this check the else-if fallback for raw-map payloads is unreachable.
            if let featuresModel = try? decoder.decode(FeaturesDataModel.self, from: featuresData),
               featuresModel.features != nil || featuresModel.encryptedFeatures != nil {
                initialContextualBandits = parsePreloadedContextualBandits(
                    from: featuresModel,
                    encryptionKey: growthBookBuilderModel.encryptionKey
                )
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
            contextualBandits: initialContextualBandits,
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

    /// Extracts the `contextualBandits` section from a preloaded (offline-mode) payload, decrypting
    /// it first when the payload uses `encryptedContextualBandits`.
    ///
    /// Returns `nil` when the payload carries no bandits or when decryption fails — a missing
    /// definition makes contextual bandit rules fall back to aggregate/equal weights rather than
    /// failing evaluation.
    private func parsePreloadedContextualBandits(from model: FeaturesDataModel, encryptionKey: String?) -> JSON? {
        if let encryptedContextualBandits = model.encryptedContextualBandits,
           !encryptedContextualBandits.isEmpty {
            guard let encryptionKey, !encryptionKey.isEmpty else {
                logger.error("Preloaded payload has encryptedContextualBandits but no encryption key was provided")
                return nil
            }
            guard let contextualBandits = Crypto().getContextualBanditsFromEncryptedFeatures(
                encryptedString: encryptedContextualBandits,
                encryptionKey: encryptionKey
            ) else {
                logger.error("Failed to decrypt contextual bandits from preloaded payload")
                return nil
            }
            return contextualBandits
        }
        return model.contextualBandits
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
    /// True once the session's contextual bandit definitions have been applied.
    ///
    /// Bandits need a latch of their own rather than reusing `sessionEstablished`: on a network
    /// fetch the features callback fires first and would already have latched, which would block
    /// the bandits arriving in the very same payload. Bandit weights decide which variation a user
    /// is bucketed into, so under stableSession they must be frozen for the session just like the
    /// features are.
    private var banditsEstablished: Bool = false

    deinit {
        contextManager.getGlobalConfig().pluginRegistry.close()
    }

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

        // Latch the bandits before featureVM is constructed — its init reads the cache and can
        // already deliver a bandits callback. A payload supplied to the builder defines the
        // session's bandits, so under stableSession later payloads must not replace them.
        // Safe to set without withLock: the object has not yet escaped to other threads.
        if contextManager.getGlobalConfig().stableSession,
           contextManager.getEvaluationData().contextualBandits != nil {
            banditsEstablished = true
        }

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

        let clientKey = globalConfig.clientKey ?? ""
        globalConfig.pluginRegistry.initialize(clientKey: clientKey)
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
            contextualBandits: context.contextualBandits,
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
        withLock {
            cachingManager.clearCache()
        }
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
                contextualBandits: evalData.contextualBandits,
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

    /// Get the value of a feature decoded into a `Decodable` type, with a fallback.
    ///
    /// Use this for structured values (objects and arrays). For primitive scalars
    /// (`Int`/`String`/`Bool`/`Double`) the dedicated overloads below are preferred —
    /// they read the value directly and avoid JSON fragment decoding edge cases.
    /// - Parameters:
    ///   - id: feature key
    ///   - type: the type to decode into
    ///   - defaultValue: returned if the feature is missing or cannot be decoded as `T`
    /// - Returns: the decoded value, or `defaultValue`
    public func getFeatureValue<T: Decodable>(feature id: String, as type: T.Type, default defaultValue: T) -> T {
        withLock {
            guard let value = _evalFeature(id: id).value,
                  let data = try? value.rawData(),
                  let decoded = try? JSONDecoder().decode(T.self, from: data)
            else { return defaultValue }
            return decoded
        }
    }

    /// Get an `Int` feature value, with a fallback.
    public func getFeatureValue(feature id: String, as type: Int.Type, default defaultValue: Int) -> Int {
        withLock { _evalFeature(id: id).value?.int ?? defaultValue }
    }

    /// Get a `String` feature value, with a fallback.
    public func getFeatureValue(feature id: String, as type: String.Type, default defaultValue: String) -> String {
        withLock { _evalFeature(id: id).value?.string ?? defaultValue }
    }

    /// Get a `Bool` feature value, with a fallback.
    public func getFeatureValue(feature id: String, as type: Bool.Type, default defaultValue: Bool) -> Bool {
        withLock { _evalFeature(id: id).value?.bool ?? defaultValue }
    }

    /// Get a `Double` feature value, with a fallback.
    public func getFeatureValue(feature id: String, as type: Double.Type, default defaultValue: Double) -> Double {
        withLock { _evalFeature(id: id).value?.double ?? defaultValue }
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

    func featuresFetchFailed(error: SDKError, isRemote: Bool) {}

    func featuresUpdateIsComplete(error: SDKError?, isRemote: Bool) {
        withLock {
            refreshHandler?(error)
        }
    }

    private func getEvalContext() -> EvalContext {
        contextManager.getEvalContext()
    }

    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}

    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        withLock {
            self.contextManager.updateEvalData { data in
                data.savedGroups = savedGroups
            }
        }
    }

    func contextualBanditsFetchFailed(error: SDKError, isRemote: Bool) {}

    func contextualBanditsFetchedSuccessfully(contextualBandits: JSON, isRemote: Bool) {
        withLock {
            let stableSession = contextManager.getGlobalConfig().stableSession

            // Applying new bandit weights mid-session would re-bucket users, which is exactly what
            // stableSession exists to prevent. Cache-only from the second payload onwards.
            if stableSession && banditsEstablished {
                if isRemote {
                    logger.info("stableSession: new contextual bandits received from network — cached for next session, not applied now")
                } else {
                    logger.debug("stableSession: ignoring cached contextual bandits — session bandits already established")
                }
                return
            }

            self.contextManager.updateEvalData { data in
                data.contextualBandits = contextualBandits
            }

            if stableSession {
                banditsEstablished = true
            }
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
        contextManager.getGlobalConfig().pluginRegistry.onFeatureEvaluated(featureKey: id, result: result, attributes: context.userContext.attributes)
        return result
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    /// - Parameter id: String
    /// - Returns: Bool
    @objc public func isOn(feature id: String) -> Bool {
        withLock { _evalFeature(id: id).isOn }
    }

    /// The isOff method takes a single string argument, which is the unique identifier for the feature and returns whether the feature is off.
    /// - Parameter id: String
    /// - Returns: Bool
    @objc public func isOff(feature id: String) -> Bool {
        withLock { _evalFeature(id: id).isOff }
    }

    /// Evaluate every known feature and return their results keyed by feature id.
    /// - Returns: a dictionary of feature id to its `FeatureResult`
    @objc public func getAllFeatureResults() -> [String: FeatureResult] {
        withLock {
            let features = contextManager.getEvaluationData().features
            var results: [String: FeatureResult] = [:]
            results.reserveCapacity(features.count)
            for key in features.keys {
                results[key] = _evalFeature(id: key)
            }
            return results
        }
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

    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {
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
