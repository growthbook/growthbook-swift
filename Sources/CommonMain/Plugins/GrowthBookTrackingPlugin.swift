import Foundation

/// A built-in GrowthBook plugin that batches experiment and feature evaluation events
/// and POSTs them to the GrowthBook ingest endpoint.
///
/// **Wire contract**
/// - Endpoint:  POST `{ingestorHost}/track?client_key={clientKey}`
/// - Default host: `https://us1.gb-ingest.com`
/// - Body: a plain JSON array of `IngestEnvelope` payloads
/// - Headers: `Content-Type: application/json`, `User-Agent: growthbook-swift-sdk/{version}`
///
/// If initialised with an empty `clientKey` the plugin degrades to no-op behaviour
/// so it never crashes the host app.
public final class GrowthBookTrackingPlugin: NSObject, GrowthBookPlugin {

    // MARK: - Config

    public struct Config {
        public let ingestorHost: String
        public let batchSize: Int
        public let batchTimeout: TimeInterval
        /// How many recent event keys to remember when suppressing duplicates. Zero turns
        /// deduplication off and sends every evaluation.
        public let dedupeCacheSize: Int
        /// When false, feature evaluations stop being reported. Experiment exposures and events
        /// raised through `logEvent` are unaffected — an app that only needs exposures can drop
        /// the far larger volume of usage events without losing its experiment data.
        public let enableFeatureUsageEvents: Bool

        public static let defaultIngestorHost = "https://us1.gb-ingest.com"
        public static let defaultBatchSize    = 100
        public static let defaultBatchTimeout: TimeInterval = 10.0
        public static let defaultDedupeCacheSize = 1000

        public init(
            ingestorHost: String = defaultIngestorHost,
            batchSize: Int = defaultBatchSize,
            batchTimeout: TimeInterval = defaultBatchTimeout,
            dedupeCacheSize: Int = defaultDedupeCacheSize,
            enableFeatureUsageEvents: Bool = true
        ) {
            self.ingestorHost = ingestorHost
            self.batchSize = batchSize
            self.batchTimeout = batchTimeout
            self.dedupeCacheSize = dedupeCacheSize
            self.enableFeatureUsageEvents = enableFeatureUsageEvents
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
    private let dedupeCache: DedupeCache

    private let queue = DispatchQueue(label: "com.growthbook.tracking-plugin", qos: .utility)
    // Used to detect re-entrant calls to close() from deinit triggered on the queue thread.
    private static let queueKey = DispatchSpecificKey<Bool>()
    // Tracks sends that already left `eventQueue`, so close() can wait for them too.
    private let inFlight = DispatchGroup()

    private let urlSession: URLSession
    // Non-nil only in tests — bypasses URLSession entirely.
    private let sendHandler: ((URLRequest, @escaping (Bool) -> Void) -> Void)?

    // MARK: - Init

    public init(config: Config = Config()) {
        self.config = config
        self.dedupeCache = DedupeCache(capacity: config.dedupeCacheSize)

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.requestCachePolicy = .reloadIgnoringLocalCacheData
        self.urlSession = URLSession(configuration: sessionConfig)
        self.sendHandler = nil
        super.init()
        queue.setSpecific(key: Self.queueKey, value: true)
    }

    /// Objective-C entry point. `Config` is a Swift struct and cannot cross the bridge, so its
    /// fields are taken individually here.
    @objc public convenience init(
        ingestorHost: String,
        batchSize: Int,
        batchTimeout: TimeInterval,
        dedupeCacheSize: Int,
        enableFeatureUsageEvents: Bool
    ) {
        self.init(config: Config(
            ingestorHost: ingestorHost,
            batchSize: batchSize,
            batchTimeout: batchTimeout,
            dedupeCacheSize: dedupeCacheSize,
            enableFeatureUsageEvents: enableFeatureUsageEvents
        ))
    }

    /// Objective-C entry point using the defaults.
    @objc public convenience override init() {
        self.init(config: Config())
    }

    // Internal — lets tests intercept requests without URLProtocol. The completion reports whether
    // the send succeeded, which decides if the batch's dedupe keys survive.
    init(
        config: Config = Config(),
        send: @escaping (URLRequest, @escaping (Bool) -> Void) -> Void
    ) {
        self.config = config
        self.dedupeCache = DedupeCache(capacity: config.dedupeCacheSize)
        let sessionConfig = URLSessionConfiguration.default
        self.urlSession = URLSession(configuration: sessionConfig)
        self.sendHandler = send
        super.init()
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
            self.enqueue(.experimentViewed(ExperimentViewedEvent(experiment: experiment, result: result, attributes: attributes ?? JSON([:]))))
        }
    }

    public func onFeatureEvaluated(featureKey: String, result: FeatureResult, attributes: JSON?) {
        guard config.enableFeatureUsageEvents else { return }
        queue.async {
            guard self.isInitialized else { return }
            self.enqueue(.featureEvaluated(FeatureEvaluatedEvent(featureKey: featureKey, result: result, attributes: attributes ?? JSON([:]))))
        }
    }

    public func logEvent(eventName: String, properties: JSON?, attributes: JSON?) {
        queue.async {
            guard self.isInitialized else { return }
            self.enqueue(.custom(CustomEvent(eventName: eventName, properties: properties, attributes: attributes ?? JSON([:]))))
        }
    }

    /// Sends whatever is buffered and waits for every request already accepted to finish, leaving
    /// the plugin running.
    ///
    /// The wait is capped at `batchTimeout`, so a request slower than that is still in flight when
    /// this returns — a hung connection delays the caller by at most that long rather than
    /// indefinitely, at the cost of making the return no proof of delivery.
    ///
    /// The timer keeps its schedule: this is the call an app makes on the way to the background,
    /// where the buffer must be delivered but recording resumes on the next foreground. `close`
    /// is the one that ends the plugin.
    public func flush() {
        if DispatchQueue.getSpecific(key: Self.queueKey) == true {
            flushAndWaitOnQueue()
        } else {
            queue.sync { self.flushAndWaitOnQueue() }
        }
    }

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
        // A flag that is read on every screen produces the same evaluation over and over; sending
        // each one costs bandwidth and tells the ingestor nothing it did not already have.
        if let key = event.dedupeKey, dedupeCache.insertAndReportDuplicate(key) {
            return
        }

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

    private func flushAndWaitOnQueue() {
        flushOnQueue()
        // Waiting on the buffer alone would return immediately whenever a flush has just handed its
        // events to a request, so wait on the in-flight sends — the batch above is one of them.
        _ = inFlight.wait(timeout: .now() + config.batchTimeout)
    }

    private func closeOnQueue() {
        // Dropping this makes the plugin inert even if a callback reaches it after shutdown. The
        // registry latches too, but it releases its lock before dispatching, so an evaluation can
        // pass that check and arrive here while a concurrent close is finishing. Anything already
        // queued behind this runs first — the serial queue orders it — so events admitted before
        // shutdown are still delivered by the flush below.
        isInitialized = false

        flushTimer?.cancel()
        flushTimer = nil
        let events = eventQueue
        eventQueue = []
        if !events.isEmpty {
            post(events: events, completion: nil)
        }
        // Waiting on `eventQueue` alone would return immediately whenever a flush has just
        // handed its events to a request, so wait on the in-flight sends instead — the batch
        // posted above is one of them.
        _ = inFlight.wait(timeout: .now() + config.batchTimeout)
    }

    private func post(events: [IngestEvent], completion: (() -> Void)?) {
        let key = clientKey

        // The keys were recorded when these events were accepted, before anything was known about
        // whether they would arrive. A batch that never lands has to give them back, or the
        // evaluations it carried stay suppressed — and because re-evaluating one refreshes its
        // place in the cache, they would never age out either.
        let dedupeKeys = events.compactMap(\.dedupeKey)

        guard
            let body = try? JSONEncoder().encode(events),
            let url = URL(string: "\(config.ingestorHost)/track?client_key=\(key)")
        else {
            releaseDedupeKeys(dedupeKeys)
            completion?()
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("growthbook-swift-sdk/\(Self.sdkVersion)", forHTTPHeaderField: "User-Agent")

        // Balanced in `finish`, which every send path calls exactly once.
        inFlight.enter()
        let finish: (Bool) -> Void = { [weak self, inFlight] succeeded in
            if !succeeded { self?.releaseDedupeKeys(dedupeKeys) }
            inFlight.leave()
            completion?()
        }

        if let handler = sendHandler {
            handler(request, finish)
        } else {
            urlSession.dataTask(with: request) { _, response, error in
                // No response at all is a failure; a response the ingestor rejected is one too.
                // Anything 2xx counts as delivered — the body is not read.
                let status = (response as? HTTPURLResponse)?.statusCode
                finish(error == nil && (status.map { (200..<300).contains($0) } ?? false))
            }.resume()
        }
    }

    /// Lets a failed batch's events be reported again. Dispatched onto the queue when called from
    /// a URLSession callback; run inline when the caller is already on it, so a send that fails
    /// synchronously has given the keys back before the next event is admitted.
    private func releaseDedupeKeys(_ keys: [String]) {
        guard !keys.isEmpty else { return }

        if DispatchQueue.getSpecific(key: Self.queueKey) == true {
            for key in keys { dedupeCache.remove(key) }
        } else {
            queue.async { for key in keys { self.dedupeCache.remove(key) } }
        }
    }
}
