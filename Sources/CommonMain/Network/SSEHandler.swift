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
    private var operationQueue: OperationQueue
    private var mainQueue = DispatchQueue.main
    private var urlSession: URLSession?

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
    }

    public func onConnect(onConnect: @escaping (() -> ())) {
        self.onConnect = onConnect
    }

    @available(*, deprecated, renamed: "onDisconnect", message: "Use `onDisconnect` instead")
    public func onDissconnect(onDisconnect: @escaping ((Int?, Bool?, NSError?) -> ())) {
        self.onDisconnect(onDisconnect: onDisconnect)
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
        mainQueue.async { [weak self] in self?.onConnect?() }
    }

    open func urlSession(_ session: URLSession,
                         task: URLSessionTask,
                         didCompleteWithError error: Error?) {

        guard let responseStatusCode = (task.response as? HTTPURLResponse)?.statusCode else {
            mainQueue.async { [weak self] in self?.onDisconnect?(nil, nil, error as NSError?) }
            return
        }

        let reconnect = shouldReconnect(statusCode: responseStatusCode)
        mainQueue.async { [weak self] in self?.onDisconnect?(responseStatusCode, reconnect, nil) }
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
    
    private func shouldReconnect(statusCode: Int) -> Bool {
        switch statusCode {
        case 200..<300:
            return true
        default:
            return false
        }
    }
}
