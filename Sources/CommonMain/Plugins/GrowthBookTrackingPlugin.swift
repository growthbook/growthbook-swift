import Foundation

/// A built-in GrowthBook plugin that batches experiment and feature evaluation events
/// and POSTs them to the GrowthBook ingest endpoint.
///
/// **Wire contract**
/// - Endpoint:  POST `{ingestorHost}/track?client_key={clientKey}`
/// - Default host: `https://us1.gb-ingest.com`
/// - Body: `[{ "event": "...", ... }, ...]`  (plain JSON array)
/// - Headers: `Content-Type: application/json`, `User-Agent: growthbook-swift-sdk/{version}`
///
/// If initialised with an empty `clientKey` the plugin degrades to no-op behaviour
/// so it never crashes the host app.
public final class GrowthBookTrackingPlugin: GrowthBookPlugin {

    // MARK: - Config

    public struct Config {
        public let ingestorHost: String
        public let batchSize: Int
        public let batchTimeout: TimeInterval

        public static let defaultIngestorHost = "https://us1.gb-ingest.com"
        public static let defaultBatchSize    = 100
        public static let defaultBatchTimeout: TimeInterval = 10.0

        public init(
            ingestorHost: String = defaultIngestorHost,
            batchSize: Int = defaultBatchSize,
            batchTimeout: TimeInterval = defaultBatchTimeout
        ) {
            self.ingestorHost = ingestorHost
            self.batchSize = batchSize
            self.batchTimeout = batchTimeout
        }
    }

    // MARK: - State

    private static let sdkVersion = gbSdkVersion

    private let config: Config

    // All mutable state is accessed exclusively from `queue`.
    private var clientKey: String = ""
    private var isInitialized = false
    private var eventQueue: [IngestEvent] = []
    private var flushTimer: DispatchSourceTimer?

    private let queue = DispatchQueue(label: "com.growthbook.tracking-plugin", qos: .utility)
    // Used to detect re-entrant calls to close() from deinit triggered on the queue thread.
    private static let queueKey = DispatchSpecificKey<Bool>()

    private let urlSession: URLSession
    // Non-nil only in tests — bypasses URLSession entirely.
    private let sendHandler: ((URLRequest, @escaping () -> Void) -> Void)?

    // MARK: - Init

    public init(config: Config = Config()) {
        self.config = config

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: sessionConfig)
        self.sendHandler = nil
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    // Internal — lets tests intercept requests without URLProtocol.
    init(
        config: Config = Config(),
        sendHandler: @escaping (URLRequest, @escaping () -> Void) -> Void
    ) {
        self.config = config
        let sessionConfig = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: sessionConfig)
        self.sendHandler = sendHandler
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    deinit {
        close()
    }

    // MARK: - GrowthBookPlugin

    public func initialize(clientKey: String) {
        guard !clientKey.isEmpty else { return }
        queue.async {
            self.clientKey = clientKey
            self.isInitialized = true
            self.startTimer()
        }
    }

    public func onExperimentViewed(experiment: Experiment, result: ExperimentResult, attributes: JSON?) {
        queue.async {
            guard self.isInitialized else { return }
            self.enqueue(.experimentViewed(ExperimentViewedEvent(experiment: experiment, result: result, attributes: Self.mergedAttributes(attributes))))
        }
    }

    public func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        queue.async {
            guard self.isInitialized else { return }
            self.enqueue(.featureEvaluated(FeatureEvaluatedEvent(featureKey: featureKey, result: result, attributes: Self.mergedAttributes(attributes))))
        }
    }

    private static func mergedAttributes(_ userAttributes: JSON?) -> JSON {
        var merged: [String: Any] = [
            "sdk_language": "swift",
            "sdk_version": sdkVersion
        ]
        if let dict = userAttributes?.object as? [String: Any] {
            for (key, value) in dict { merged[key] = value }
        }
        return JSON(merged)
    }

    /// Stops the flush timer and synchronously sends all buffered events before returning.
    public func close() {
        if DispatchQueue.getSpecific(key: Self.queueKey) == true {
            // Already on the queue (e.g. deinit triggered by a queue closure).
            // Execute inline to avoid deadlocking on queue.sync.
            closeOnQueue()
        } else {
            // queue.sync waits for all pending work then runs closeOnQueue.
            // The closure completes fully before sync returns — no retain-after-deinit issue.
            queue.sync { self.closeOnQueue() }
        }
    }

    // MARK: - Private helpers (called from queue)

    private func enqueue(_ event: IngestEvent) {
        eventQueue.append(event)
        if eventQueue.count >= config.batchSize {
            flushOnQueue()
        }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + config.batchTimeout, repeating: config.batchTimeout)
        timer.setEventHandler { [weak self] in self?.flushOnQueue() }
        timer.resume()
        flushTimer = timer
    }

    private func flushOnQueue() {
        let events = eventQueue
        eventQueue = []
        guard !events.isEmpty else { return }
        post(events: events, completion: nil)
    }

    private func closeOnQueue() {
        flushTimer?.cancel()
        flushTimer = nil
        let events = eventQueue
        eventQueue = []
        guard !events.isEmpty else { return }
        let semaphore = DispatchSemaphore(value: 0)
        post(events: events) { semaphore.signal() }
        _ = semaphore.wait(timeout: .now() + config.batchTimeout)
    }

    private func post(events: [IngestEvent], completion: (() -> Void)?) {
        let key = clientKey

        guard
            let body = try? JSONEncoder().encode(events),
            let url = URL(string: "\(config.ingestorHost)/track?client_key=\(key)")
        else {
            completion?()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("growthbook-swift-sdk/\(Self.sdkVersion)", forHTTPHeaderField: "User-Agent")

        if let handler = sendHandler {
            handler(request) { completion?() }
        } else {
            urlSession.dataTask(with: request) { _, _, _ in completion?() }.resume()
        }
    }
}
