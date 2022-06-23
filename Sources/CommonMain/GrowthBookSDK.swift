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
    var apiKey: String?
    var hostURL: String?
    var features: Data?
    var attributes: JSON
    var trackingClosure: TrackingCallback
    var logLevel: Level = .info
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON?
}

/// GrowthBookBuilder - inItializer for GrowthBook SDK for Apps
/// - HostURL - Server URL
/// - UserAttributes - User Attributes
/// - Tracking Closure - Track Events for Experiments
@objc public class GrowthBookBuilder: NSObject, GrowthBookProtocol {
    var growthBookBuilderModel: GrowthBookModel

    private var refreshHandler: CacheRefreshHandler?
    private var networkDispatcher: NetworkProtocol = CoreNetworkClient()

    @objc public init(apiKey: String? = nil, hostURL: String, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil) {
        growthBookBuilderModel = GrowthBookModel(apiKey: apiKey, hostURL: hostURL, attributes: JSON(attributes), trackingClosure: trackingCallback)
        self.refreshHandler = refreshHandler
    }

    @objc public init(features: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil) {
        growthBookBuilderModel = GrowthBookModel(features: features, attributes: JSON(attributes), trackingClosure: trackingCallback)
    }

    init(apiKey: String? = nil, hostURL: String, attributes: JSON, trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?) {
        growthBookBuilderModel = GrowthBookModel(apiKey: apiKey, hostURL: hostURL, attributes: JSON(attributes), trackingClosure: trackingCallback)
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

    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            apiKey: growthBookBuilderModel.apiKey,
            hostURL: growthBookBuilderModel.hostURL,
            isEnabled: growthBookBuilderModel.isEnabled,
            attributes: growthBookBuilderModel.attributes,
            forcedVariations: growthBookBuilderModel.forcedVariations,
            isQaMode: growthBookBuilderModel.isQaMode,
            trackingClosure: growthBookBuilderModel.trackingClosure
        )
        if let features = growthBookBuilderModel.features {
            CachingManager.shared.saveContent(fileName: Constants.featureCache, content: features)
        }
        return GrowthBookSDK(context: gbContext, refreshHandler: refreshHandler, networkDispatcher: networkDispatcher)
    }
}

/// The main export of the libraries is a simple GrowthBook wrapper class that takes a Context object in the constructor.
///
/// It exposes two main methods: feature and run.
@objc public class GrowthBookSDK: NSObject, FeaturesFlowDelegate {
    private var refreshHandler: CacheRefreshHandler?
    private var networkDispatcher: NetworkProtocol
    public var gbContext: Context

    init(context: Context,
         refreshHandler: CacheRefreshHandler? = nil,
         logLevel: Level = .info,
         networkDispatcher: NetworkProtocol = CoreNetworkClient(),
         features: Features? = nil) {
        gbContext = context
        self.refreshHandler = refreshHandler
        self.networkDispatcher = networkDispatcher
        super.init()
        if let features = features {
            gbContext.features = features
        } else {
            refreshCache()
        }

        // Logger setup. if we have logHandler we have to re-initialise logger
        logger.minLevel = logLevel
    }

    /// Manually Refresh Cache
    @objc public func refreshCache() {
        let featureVM = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: networkDispatcher))
        var apiUrl: String? = nil
        if let hostUrl = gbContext.hostURL {
            if let apiKey = gbContext.apiKey {
                apiUrl = hostUrl + Constants.featurePath + apiKey
            } else {
                apiUrl = hostUrl
            }
        }
        featureVM.fetchFeatures(apiUrl: apiUrl)
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
        return FeatureEvaluator().evaluateFeature(context: gbContext, featureKey: id).value ?? defaultValue
    }

    @objc public func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool) {
        gbContext.features = features
        if isRemote {
            refreshHandler?(true)
        }
    }

    @objc public func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        if isRemote {
            refreshHandler?(false)
        }
    }

    /// The feature method takes a single string argument, which is the unique identifier for the feature and returns a FeatureResult object.
    @objc public func evalFeature(id: String) -> FeatureResult {
        return FeatureEvaluator().evaluateFeature(context: gbContext, featureKey: id)
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
