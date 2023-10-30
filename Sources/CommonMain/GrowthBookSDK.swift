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
    var url: String?
    var encryptionKey: String?
    var features: Data?
    var attributes: JSON
    var trackingClosure: TrackingCallback
    var logLevel: Level = .info
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON?
    var cacheDirectory: CacheDirectory = .applicationSupport
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

    @objc public init(url: String, encryptionKey: String? = nil, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil) {
        growthBookBuilderModel = GrowthBookModel(url: url, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback)
        self.refreshHandler = refreshHandler
    }

    @objc public init(features: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil) {
        growthBookBuilderModel = GrowthBookModel(features: features, attributes: JSON(attributes), trackingClosure: trackingCallback)
        self.refreshHandler = refreshHandler
    }

    init(url: String, encryptionKey: String? = nil, attributes: JSON, trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?) {
        growthBookBuilderModel = GrowthBookModel(url: url, encryptionKey: encryptionKey, attributes: JSON(attributes), trackingClosure: trackingCallback)
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
    
    @objc public func setCacheDirectory(_ directory: CacheDirectory) -> GrowthBookBuilder {
        CachingManager.shared.updateCacheDirectory(directory)
        return self
    }

    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            url: growthBookBuilderModel.url,
            encryptionKey: growthBookBuilderModel.encryptionKey,
            isEnabled: growthBookBuilderModel.isEnabled,
            attributes: growthBookBuilderModel.attributes,
            forcedVariations: growthBookBuilderModel.forcedVariations,
            isQaMode: growthBookBuilderModel.isQaMode,
            trackingClosure: growthBookBuilderModel.trackingClosure
        )
        if let features = growthBookBuilderModel.features {
            CachingManager.shared.saveContent(fileName: Constants.featureCache, content: features)
        }
        return GrowthBookSDK(context: gbContext, refreshHandler: refreshHandler, networkDispatcher: networkDispatcher, attributes: growthBookBuilderModel.attributes)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject, FeaturesFlowDelegate {
    private var refreshHandler: CacheRefreshHandler?
    private var networkDispatcher: NetworkProtocol
    public var gbContext: Context
    private var featureVM: FeaturesViewModel!
    private var attributeOverrides: JSON

    init(context: Context,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil, attributes: JSON) {
        gbContext = context
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        self.attributeOverrides = attributes
        super.init()
        self.featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher))
        if let features = features {
            gbContext.features = features
        } else {
            featureVM.encryptionKey = context.encryptionKey ?? ""
            refreshCache()
        }
        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel
    }

    /// Manually Refresh Cache
    @objc public func refreshCache() {
        featureVM.fetchFeatures(apiUrl: gbContext.url)
    }
    
    /// This function removes all files and subdirectories within the designated cache directory, which is a specific subdirectory within the app's cache directory.
    @objc public func clearCache() {
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

    /// Get the value of the feature with a fallback
    public func getFeatureValue(feature id: String, default defaultValue: JSON) -> JSON {
        return FeatureEvaluator(context: gbContext, featureKey: id, attributeOverrides: attributeOverrides).evaluateFeature().value ?? defaultValue
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

    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    @objc public func evalFeature(id: String) -> FeatureResult {
        return FeatureEvaluator(context: gbContext, featureKey: id, attributeOverrides: attributeOverrides).evaluateFeature()
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    @objc public func isOn(feature id: String) -> Bool {
        return evalFeature(id: id).isOn
    }

    /// The run method takes an Experiment object and returns an experiment result
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        return ExperimentEvaluator().evaluateExperiment(context: gbContext, experiment: experiment)
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    @objc public func setAttributes(attributes: Any) {
        gbContext.attributes = JSON(attributes)
    }
}
