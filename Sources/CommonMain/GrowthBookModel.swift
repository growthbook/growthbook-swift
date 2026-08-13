import Foundation

public struct GrowthBookModel {
    /// API Host.
    public var apiHost: String?
    /// Streaming Host.
    public var streamingHost: String?
    /// Growthbook client key.
    public var clientKey: String?
    /// Encryption key.
    public var encryptionKey: String?
    /// Features.
    public var features: Data?
    /// Attributes used for evaluation.
    public var attributes: JSON
    /// Tracking closure that will be called when an experiment evaluation is completed.
    public var trackingClosure: TrackingCallback
    /// Log level.
    public var logLevel: Level = .info
    /// If `true`, the SDK will be in QA mode.
    public var isQaMode: Bool = false
    /// If `true`, the SDK will be enabled.
    public var isEnabled: Bool = true
    /// Forced experiment **variations**.
    public var forcedVariations: JSON?
    /// Cache directory.
    public var cacheDirectory: CacheDirectory = .applicationSupport
    /// Sticky bucket service.
    public var stickyBucketService: StickyBucketServiceProtocol?
    /// If `true`, the SDK will sync features in the background with the `streamingHost` via SSE.
    public var backgroundSync: Bool
    /// If `true`, features fetched remotely are cached but not applied to the running SDK.
    public var stableSession: Bool = false
    /// If `true`, the SDK will use remote features evaluation.
    public var remoteEval: Bool
    /// Additional API request headers.
    public var apiRequestHeaders: [String: String]? = nil
    /// Additional streaming host request headers.
    public var streamingHostRequestHeaders: [String: String]? = nil
    /// Forced feature **values**.
    public var forcedFeatureValues: JSON?
    /// Plugins that receive experiment and feature evaluation events.
    public var plugins: [GrowthBookPlugin] = []

    /// Initialize GrowthBookModel.
    ///
    /// - Parameters:
    ///   - apiHost: API Host.
    ///   - streamingHost: Streaming Host.
    ///   - clientKey: Growthbook client key.
    ///   - encryptionKey: Encryption key.
    ///   - features: Features.
    ///   - attributes: Attributes used for evaluation.
    ///   - trackingClosure: Tracking closure that will be called when an experiment evaluation is completed.
    ///   - logLevel: Log Level.
    ///   - isQaMode: If `true`, the SDK will be in QA mode.
    ///   - isEnabled: If `true`, the SDK will be enabled.
    ///   - forcedVariations: Forced experiment **variations**.
    ///   - cacheDirectory: Cache directory.
    ///   - stickyBucketService: Sticky Bucket service.
    ///   - backgroundSync: If `true`, the SDK will sync features in the background with the `streamingHost` via SSE.
    ///   - stableSession: If `true`, features fetched remotely are cached but not applied to the running SDK.
    ///   - remoteEval: If `true`, the SDK will use remote features evaluation.
    ///   - apiRequestHeaders: Additional API request headers.
    ///   - streamingHostRequestHeaders: Additional streaming host request headers.
    ///   - forcedFeatureValues: Forced feature **values**.
    public init(
        apiHost: String? = nil,
        streamingHost: String? = nil,
        clientKey: String? = nil,
        encryptionKey: String? = nil,
        features: Data? = nil,
        attributes: JSON = [:],
        trackingClosure: @escaping TrackingCallback = { _, _ in },
        logLevel: Level = .info,
        isQaMode: Bool = false,
        isEnabled: Bool = true,
        forcedVariations: JSON? = nil,
        cacheDirectory: CacheDirectory = .applicationSupport,
        stickyBucketService: StickyBucketServiceProtocol? = nil,
        backgroundSync: Bool = false,
        stableSession: Bool = false,
        remoteEval: Bool = false,
        apiRequestHeaders: [String: String]? = nil,
        streamingHostRequestHeaders: [String: String]? = nil,
        forcedFeatureValues: JSON? = nil
    ) {
        self.apiHost = apiHost
        self.streamingHost = streamingHost
        self.clientKey = clientKey
        self.encryptionKey = encryptionKey
        self.features = features
        self.attributes = attributes
        self.trackingClosure = trackingClosure
        self.logLevel = logLevel
        self.isQaMode = isQaMode
        self.isEnabled = isEnabled
        self.forcedVariations = forcedVariations
        self.cacheDirectory = cacheDirectory
        self.stickyBucketService = stickyBucketService
        self.backgroundSync = backgroundSync
        self.stableSession = stableSession
        self.remoteEval = remoteEval
        self.apiRequestHeaders = apiRequestHeaders
        self.streamingHostRequestHeaders = streamingHostRequestHeaders
        self.forcedFeatureValues = forcedFeatureValues
    }
}
