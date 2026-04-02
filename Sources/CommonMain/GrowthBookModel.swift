import Foundation

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
    var stableSession: Bool = false
    var remoteEval: Bool
    var apiRequestHeaders: [String: String]? = nil
    var streamingHostRequestHeaders: [String: String]? = nil
    var forcedFeatureValues: JSON?

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
    ///   - forcedVariations: Forced experiment *variations*.
    ///   - cacheDirectory: Cache directory.
    ///   - stickyBucketService: Sticky Bucket service.
    ///   - backgroundSync: If `true`, the SDK will sync features in the background with the `streamingHost` via SSE.
    ///   - stableSession: If `true`, features fetched remotely are cached but not applied to the running SDK.
    ///   - remoteEval: If `true`, the SDK will use remote features evaluation.
    ///   - apiRequestHeaders: Additional API request headers.
    ///   - streamingHostRequestHeaders: Additional streaming host request headers.
    ///   - forcedFeatureValues: Forced feature *values*.
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
