import Foundation

/// SDKBuilder - Root Class for SDK Initializers for GrowthBook SDK
protocol SDKBuilderProtocol: AnyObject {
    var sdkBuilder: SDKBuilder { get set }

    func setForcedVariations(forcedVariations: [String: Int]) -> SDKBuilderApp
    func setQAMode(isEnabled: Bool) -> SDKBuilderApp
    func setEnabled(isEnabled: Bool) -> SDKBuilderApp
    func initializer() -> GrowthBookSDK
}

public struct SDKBuilder {
    var apiKey: String?
    var hostURL: String?
    var json: Data?
    var attributes: JSON
    var trackingClosure: TrackingCallback
    var logLevel: Level = .info
    var isQaMode: Bool = false
    var isEnabled: Bool = true
    var forcedVariations: JSON?
}

/// SDKBuilder - inItializer for GrowthBook SDK for Apps
/// - APIKey - API Key
/// - HostURL - Server URL
/// - UserAttributes - User Attributes
/// - Tracking Closure - Track Events for Experiments
@objc public class SDKBuilderApp: NSObject, SDKBuilderProtocol {
    var sdkBuilder: SDKBuilder

    private var refreshHandler: CacheRefreshHandler?
    private var networkDispatcher: NetworkProtocol = CoreNetworkClient()

    @objc public init(apiKey: String? = nil, hostURL: String, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler? = nil) {
        sdkBuilder = SDKBuilder(apiKey: apiKey, hostURL: hostURL, attributes: JSON(attributes), trackingClosure: trackingCallback)
        self.refreshHandler = refreshHandler
    }

    @objc public init(json: Data, attributes: [String: Any], trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?) {
        sdkBuilder = SDKBuilder(json: json, attributes: JSON(attributes), trackingClosure: trackingCallback)
    }

    init(apiKey: String, hostURL: String, attributes: JSON, trackingCallback: @escaping TrackingCallback, refreshHandler: CacheRefreshHandler?) {
        sdkBuilder = SDKBuilder(apiKey: apiKey, hostURL: hostURL, attributes: JSON(attributes), trackingClosure: trackingCallback)
        self.refreshHandler = refreshHandler
    }

    /// Set Refresh Handler - Will be called when cache is refreshed
    @objc public func setRefreshHandler(refreshHandler: @escaping CacheRefreshHandler) -> SDKBuilderApp {
        self.refreshHandler = refreshHandler
        return self
    }

    /// Set Network Client - Network Client for Making API Calls
    @objc public func setNetworkDispatcher(networkDispatcher: NetworkProtocol) -> SDKBuilderApp {
        self.networkDispatcher = networkDispatcher
        return self
    }

    /// Set log level for SDK Logger
    ///
    /// By default log level is set to `info`
    @objc public func setLogLevel(_ level: LoggerLevel) -> SDKBuilderApp {
        sdkBuilder.logLevel = Logger.getLoggingLevel(from: level)
        return self
    }

    @objc public func setForcedVariations(forcedVariations: [String: Int]) -> SDKBuilderApp {
        sdkBuilder.forcedVariations = JSON(forcedVariations)
        return self
    }

    @objc public func setQAMode(isEnabled: Bool) -> SDKBuilderApp {
        sdkBuilder.isQaMode = isEnabled
        return self
    }

    @objc public func setEnabled(isEnabled: Bool) -> SDKBuilderApp {
        sdkBuilder.isEnabled = isEnabled
        return self
    }

    @objc public func initializer() -> GrowthBookSDK {
        let gbContext = Context(
            apiKey: sdkBuilder.apiKey,
            hostURL: sdkBuilder.hostURL,
            isEnabled: sdkBuilder.isEnabled,
            attributes: sdkBuilder.attributes,
            forcedVariations: sdkBuilder.forcedVariations,
            isQaMode: sdkBuilder.isQaMode,
            trackingClosure: sdkBuilder.trackingClosure
        )
        if let json = sdkBuilder.json {
            CachingManager.shared.saveContent(fileName: Constants.featureCache, content: json)
        }
        return GrowthBookSDK(context: gbContext, refreshHandler: refreshHandler, /*logLevel: sdkBuilder.logLevel, logHandler: logHandler,*/ networkDispatcher: networkDispatcher)
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
    @objc public func feature(id: String) -> FeatureResult {
        return FeatureEvaluator().evaluateFeature(context: gbContext, featureKey: id)
    }

    /// The isOn method takes a single string argument, which is the unique identifier for the feature and returns the feature state on/off
    @objc public func isOn(feature id: String) -> Bool {
        return feature(id: id).isOn
    }

    /// The run method takes an Experiment object and returns an ExperimentResult
    @objc public func run(experiment: Experiment) -> ExperimentResult {
        return ExperimentEvaluator().evaluateExperiment(context: gbContext, experiment: experiment)
    }

    /// The setAttributes method replaces the Map of user attributes that are used to assign variations
    @objc public func setAttributes(attributes: Any) {
        gbContext.attributes = JSON(attributes)
    }
}
