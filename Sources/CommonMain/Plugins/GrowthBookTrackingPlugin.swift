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
/// **Batch defaults**
/// - batchSize: 100 events
/// - batchTimeout: 10 seconds
///
/// If initialised with an empty `clientKey` the plugin degrades to no-op behaviour
/// so it never crashes the host app.
public final class GrowthBookTrackingPlugin: GrowthBookPlugin {

    // MARK: - Configuration

    public static let defaultIngestorHost = "https://us1.gb-ingest.com"
    public static let defaultBatchSize    = 100
    public static let defaultBatchTimeout: TimeInterval = 10.0

    private static let sdkVersion = "1.0.0"

    // MARK: - State

    private let ingestorHost: String
    private let batchSize: Int
    private let batchTimeout: TimeInterval

    private var clientKey: String = ""
    private var isInitialized = false

    private var eventQueue: [IngestEvent] = []
    private let lock = NSLock()

    private var flushTimer: DispatchSourceTimer?
    private let timerQueue = DispatchQueue(label: "com.growthbook.tracking-plugin.timer", qos: .utility)

    private let urlSession: URLSession
    // Non-nil only in tests — bypasses URLSession entirely.
    private let sendHandler: ((URLRequest, @escaping () -> Void) -> Void)?

    // MARK: - Init

    public init(
        ingestorHost: String = defaultIngestorHost,
        batchSize: Int = defaultBatchSize,
        batchTimeout: TimeInterval = defaultBatchTimeout
    ) {
        self.ingestorHost = ingestorHost
        self.batchSize = batchSize
        self.batchTimeout = batchTimeout

        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: config)
        self.sendHandler = nil
    }

    // Internal — lets tests intercept requests without URLProtocol.
    init(
        ingestorHost: String = defaultIngestorHost,
        batchSize: Int = defaultBatchSize,
        batchTimeout: TimeInterval = defaultBatchTimeout,
        sendHandler: @escaping (URLRequest, @escaping () -> Void) -> Void
    ) {
        self.ingestorHost = ingestorHost
        self.batchSize = batchSize
        self.batchTimeout = batchTimeout
        let config = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: config)
        self.sendHandler = sendHandler
    }

    deinit {
        close()
    }

    // MARK: - GrowthBookPlugin

    public func initialize(clientKey: String) {
        guard !clientKey.isEmpty else { return }
        lock.lock()
        self.clientKey = clientKey
        self.isInitialized = true
        lock.unlock()
        startTimer()
    }

    public func onExperimentViewed(experiment: Experiment, result: ExperimentResult) {
        guard isReady else { return }
        enqueue(.experimentViewed(ExperimentViewedEvent(experiment: experiment, result: result)))
    }

    public func onFeatureEvaluated(featureKey: String, result: FeatureResult) {
        guard isReady else { return }
        enqueue(.featureEvaluated(FeatureEvaluatedEvent(featureKey: featureKey, result: result)))
    }

    /// Stops the flush timer and synchronously sends all buffered events before returning.
    public func close() {
        stopTimer()
        flushSync()
    }

    // MARK: - Private helpers

    private var isReady: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isInitialized
    }

    private func enqueue(_ event: IngestEvent) {
        var shouldFlush = false
        lock.lock()
        eventQueue.append(event)
        if eventQueue.count >= batchSize {
            shouldFlush = true
        }
        lock.unlock()

        if shouldFlush {
            flushAsync()
        }
    }

    private func startTimer() {
        let timer = DispatchSource.makeTimerSource(queue: timerQueue)
        timer.schedule(deadline: .now() + batchTimeout, repeating: batchTimeout)
        timer.setEventHandler { [weak self] in self?.flushAsync() }
        timer.resume()
        flushTimer = timer
    }

    private func stopTimer() {
        flushTimer?.cancel()
        flushTimer = nil
    }

    private func flushAsync() {
        let events = drainQueue()
        guard !events.isEmpty else { return }
        post(events: events, completion: nil)
    }

    private func flushSync() {
        let events = drainQueue()
        guard !events.isEmpty else { return }
        let semaphore = DispatchSemaphore(value: 0)
        post(events: events) { semaphore.signal() }
        semaphore.wait()
    }

    private func drainQueue() -> [IngestEvent] {
        lock.lock()
        defer { lock.unlock() }
        let events = eventQueue
        eventQueue = []
        return events
    }

    private func post(events: [IngestEvent], completion: (() -> Void)?) {
        lock.lock()
        let key = clientKey
        lock.unlock()

        guard
            let body = try? JSONEncoder().encode(events),
            let url = URL(string: "\(ingestorHost)/track?client_key=\(key)")
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
