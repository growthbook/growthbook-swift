import Foundation

enum SSEConnectionStatus {
    case connecting
    case connected
    case disconnected
}

class SSEHandler: NSObject, URLSessionDataDelegate {
    static let DefaultRetryTime = 1000
    public let url: URL
    public var lastEventId: String?
    public var retryTime = SSEHandler.DefaultRetryTime
    public var headers: [String: String]
    public var connectionStatus: SSEConnectionStatus

    private var onConnect: (() -> Void)?
    private var onDisconnect: ((Int?, Bool?, NSError?) -> Void)?
    private var eventListeners: [String: (_ id: String?, _ event: String?, _ data: String?) -> Void] = [:]
    private var eventHandler: EventHandler?
    var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main
    private var urlSession: URLSession?

    private(set) var retryCount = 0
    /// The ceiling the backoff climbs to and then stays at. Matches the reference SDK's
    /// `MAX_BACKOFF_MS`. Reconnecting is not abandoned at the ceiling, so this is the steady-state
    /// poll interval for as long as the server is unreachable — which is why it is minutes rather
    /// than seconds. It only applies to long outages: the backoff restarts at `retryTime` and is
    /// reset by a successful connect, so a brief drop still recovers within seconds.
    let maxRetryDelayMs = 300_000

    // Internal for testing: accepts an explicit count so tests don't need to mutate retryCount.
    //
    // Doubling in a loop rather than `retryTime * pow(2, count)`: with no attempt limit `count`
    // grows without bound, and converting the resulting Double to Int traps once it passes
    // Int.max — on 32-bit watchOS that is only a few seconds of outage away. The loop stops at the
    // ceiling instead, so the value never approaches the overflow. The base is floored at 1ms
    // because a server may send `retry: 0`, which would otherwise never grow and spin the loop.
    func backoffDelay(for count: Int) -> Int {
        var delay = max(retryTime, 1)
        var doublings = 0
        while doublings < count && delay < maxRetryDelayMs {
            delay *= 2
            doublings += 1
        }
        return min(delay, maxRetryDelayMs)
    }

    /// The backoff delay with jitter: somewhere in the upper half of the computed delay.
    ///
    /// Without it every client that lost the same host waits exactly the same time and retries in
    /// lockstep, which lands hardest on a server that is just coming back up. That did not matter
    /// while retries stopped after ten attempts; now that they continue indefinitely at the
    /// ceiling, those clients would stay synchronised for as long as the outage lasts.
    ///
    /// Jitter is applied after the ceiling rather than before it, so it still spreads clients once
    /// the delay has capped — the point at which they are most synchronised. The reference SDK
    /// multiplies before capping, so its jitter disappears at exactly that point.
    func jitteredDelay(for count: Int) -> Int {
        let delay = backoffDelay(for: count)
        guard delay > 1 else { return delay }
        return Int.random(in: (delay / 2)...delay)
    }

    var backoffDelay: Int { backoffDelay(for: retryCount) }

    public init(
        url: URL,
        headers: [String: String] = [:]
    ) {
        self.url = url
        self.headers = headers

        connectionStatus = SSEConnectionStatus.disconnected
        operationQueue = OperationQueue()
        operationQueue.maxConcurrentOperationCount = 1

        super.init()
    }

    public func connect(lastEventId: String? = nil) {
        eventHandler = EventHandler()
        connectionStatus = .connecting

        let configuration = sessionConfiguration(lastEventId: lastEventId)
        urlSession = URLSession(configuration: configuration, delegate: self, delegateQueue: operationQueue)
        urlSession?.dataTask(with: url).resume()
    }

    public func disconnect() {
        connectionStatus = .disconnected
        urlSession?.invalidateAndCancel()
        // Reset on operationQueue to avoid a data race with delegate methods
        // that also mutate retryCount on that queue.
        operationQueue.addOperation { [weak self] in self?.retryCount = 0 }
    }

    public func onConnect(onConnect: @escaping (() -> ())) {
        self.onConnect = onConnect
    }

    public func onDisconnect(onDisconnect: @escaping ((Int?, Bool?, NSError?) -> ())) {
        self.onDisconnect = onDisconnect
    }

    public func addEventListener(event: String,
                                 handler: @escaping ((_ id: String?, _ event: String?, _ data: String?) -> ())) {
        eventListeners[event] = handler
    }

    public func removeEventListener(event: String) {
        eventListeners.removeValue(forKey: event)
    }

    public func events() -> [String] {
        return Array(eventListeners.keys)
    }

    open func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        if connectionStatus != .connected {
            return
        }
        if let events = eventHandler?.append(data: data) {
            notifyReceivedEvents(events)
        }
    }

    open func urlSession(_ session: URLSession,
                         dataTask: URLSessionDataTask,
                         didReceive response: URLResponse,
                         completionHandler: @escaping (URLSession.ResponseDisposition) -> ()) {

        completionHandler(URLSession.ResponseDisposition.allow)
        connectionStatus = .connected
        retryCount = 0
        mainQueue.async { [weak self] in self?.onConnect?() }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {

        handleStreamCompletion(statusCode: (task.response as? HTTPURLResponse)?.statusCode,
                               error: error as NSError?)
    }

    /// Decides whether a finished stream should be retried, and schedules it if so.
    ///
    /// Internal rather than private so tests can drive it: the delegate callback above carries a
    /// `URLSessionTask`, which tests cannot construct.
    func handleStreamCompletion(statusCode: Int?, error: NSError?) {
        // A cancelled task means the stream was torn down deliberately — `disconnect()`, or the
        // session being invalidated — so it must not come back on its own.
        let wasCancelled = error?.domain == NSURLErrorDomain && error?.code == NSURLErrorCancelled
        if connectionStatus == .disconnected || wasCancelled {
            mainQueue.async { [weak self] in self?.onDisconnect?(statusCode, false, error) }
            return
        }

        let reconnect = shouldReconnect(statusCode: statusCode)

        // No attempt limit. A budget that runs out ends streaming for the life of the instance, so
        // a few minutes offline left features frozen until the app was relaunched. Retrying stops
        // only where it is asked to: `disconnect()` or a cancelled task, both handled above.
        if reconnect {
            let delay = jitteredDelay(for: retryCount)
            retryCount += 1
            mainQueue.asyncAfter(deadline: .now() + .milliseconds(delay)) { [weak self] in
                guard let self, self.connectionStatus != .disconnected else { return }
                self.connect(lastEventId: self.lastEventId)
            }
            mainQueue.async { [weak self] in self?.onDisconnect?(statusCode, true, error) }
        } else {
            mainQueue.async { [weak self] in self?.onDisconnect?(statusCode, false, error) }
        }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         willPerformHTTPRedirection response: HTTPURLResponse,
                         newRequest request: URLRequest,
                         completionHandler: @escaping (URLRequest?) -> Void) {

        var newRequest = request
        self.headers.forEach { newRequest.setValue($1, forHTTPHeaderField: $0) }
        completionHandler(newRequest)
    }
}

extension SSEHandler {

    func sessionConfiguration(lastEventId: String?) -> URLSessionConfiguration {

        var additionalHeaders = headers
        if let eventID = lastEventId {
            additionalHeaders["Last-Event-Id"] = eventID
        }
        additionalHeaders["Accept"] = "application/json; q=0.5"
        additionalHeaders["Accept"] = "text/event-stream"
        additionalHeaders["Cache-Control"] = "no-cache"

        let sessionConfiguration = URLSessionConfiguration.default
        sessionConfiguration.timeoutIntervalForRequest = TimeInterval(INT_MAX)
        sessionConfiguration.timeoutIntervalForResource = TimeInterval(INT_MAX)
        sessionConfiguration.httpAdditionalHeaders = additionalHeaders

        return sessionConfiguration
    }

    func readyStateOpen() {
        connectionStatus = .connected
    }
}

extension SSEHandler {

    private func notifyReceivedEvents(_ events: [SSEEvent]) {

        for event in events {
            lastEventId = event.id
            retryTime = event.retryTime ?? SSEHandler.DefaultRetryTime

            if event.onlyRetryEvent == true {
                continue
            }

            if let eventName = event.event, let eventHandler = eventListeners[eventName] {
                mainQueue.async { eventHandler(event.id, event.event, event.data) }
            }
        }
    }
    
    /// Whether a stream that finished with this status should be retried.
    ///
    /// 200 is a stream that was healthy and ended — the ordinary case, and the one the backoff was
    /// written for. 5xx and 429 are the server saying "not now": a proxy restarting mid-deploy, a
    /// gateway blip, a rate limit. Ending streaming on those left features frozen for the life of
    /// the instance over something that cleared in seconds.
    ///
    /// Everything else stays terminal. That is a deliberate difference from the reference SDK
    /// rather than parity with it: `EventSource` gives JS no status code at all, so it retries
    /// every failure including 401 and 404 — a revoked client key there reconnects forever. Here a
    /// rejection that will not change on its own is believed the first time.
    func shouldReconnect(statusCode: Int) -> Bool {
        return statusCode == 200 || statusCode == 429 || (500...599).contains(statusCode)
    }

    /// A stream that completed without an HTTP response never reached the server: DNS failure,
    /// connection loss, timeout. Those are exactly the failures a bounded backoff exists for, so
    /// they are retryable; once there *is* a response, only 200 is.
    func shouldReconnect(statusCode: Int?) -> Bool {
        guard let statusCode else { return true }
        return shouldReconnect(statusCode: statusCode)
    }
}
