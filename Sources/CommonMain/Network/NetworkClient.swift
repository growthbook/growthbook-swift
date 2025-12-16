import Foundation

/// Network Dispatcher Protocol for API Consumption
///
/// Implement this protocol to define specific implementation for Network Calls - to be made by SDK
@objc public protocol NetworkProtocol: AnyObject {
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
    func consumePOSTRequest(url: String, params: [String : Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
}

class CoreNetworkClient: NetworkProtocol {
    var apiRequestHeaders: [String: String]
    var streamingHostRequestHeaders: [String: String]
    
    // Thread-safe LRU cache with max 100 entries to prevent unbounded growth
    private let eTagCache = LruETagCache(maxSize: 100)
    
    // Regex pattern to match the desired URL pattern: "/api/features/<clientKey>"
    private lazy var featuresPathPattern: NSRegularExpression? = {
        try? NSRegularExpression(pattern: ".*/api/features/[^/]+", options: [])
    }()
    
    private lazy var urlSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil  // Disable URLCache
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: config)
    }()
    
    init(apiRequestHeaders: [String: String] = [:],
         streamingHostRequestHeaders: [String: String] = [:]) {
        self.apiRequestHeaders = apiRequestHeaders
        self.streamingHostRequestHeaders = streamingHostRequestHeaders
    }
    
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        perform(urlString: url, method: "GET", params: nil, successResult: successResult, errorResult: errorResult)
    }
    
    func consumePOSTRequest(url: String, params: [String : Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        perform(urlString: url, method: "POST", params: params, successResult: successResult, errorResult: errorResult)
    }
    
    private func perform(urlString: String, method: String, params: [String: Any]?, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        guard let url = URL(string: urlString) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in apiRequestHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        // Add ETag caching headers for GET requests matching features pattern
        if method == "GET" && matchesFeaturesPattern(urlString) {
            // Add If-None-Match header if ETag is present
            if let etag = eTagCache.get(urlString) {
                request.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            request.setValue("max-age=3600", forHTTPHeaderField: "Cache-Control")
            request.setValue("gzip, deflate, br", forHTTPHeaderField: "Accept-Encoding")
        }
        
        if let params = params {
            let bodyData = try? JSONSerialization.data(withJSONObject: params)
            if let bodyData = bodyData {
                request.httpBody = bodyData
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
                }
            }
        }
        
        urlSession.dataTask(with: request) { data, response, error in
            if let error = error {
                errorResult(error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                
                if method == "GET" && self.matchesFeaturesPattern(urlString) {
                    if #available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *) {
                        if let etag = httpResponse.value(forHTTPHeaderField: "ETag") {
                            self.eTagCache.put(urlString, etag)
                        }
                    } else {
                        let headers = httpResponse.allHeaderFields
                        let etagValue = headers["Etag"] as? String ?? headers["etag"] as? String ?? headers["ETag"] as? String
                        if let etag = etagValue {
                            self.eTagCache.put(urlString, etag)
                        }
                        
                    }
                }
                
                let status = httpResponse.statusCode
                
                // Handle 304 Not Modified - data hasn't changed
                if status == 304 {
                    let notModifiedError = NSError(domain: "HTTPError", code: 304, userInfo: [
                        NSLocalizedDescriptionKey: "Not Modified - Use cached data"
                    ])
                    errorResult(notModifiedError)
                    return
                }
                
                if status >= 400 {
                    let httpError = NSError(domain: "HTTPError", code: httpResponse.statusCode, userInfo: [
                        NSLocalizedDescriptionKey: "HTTP Error: \(httpResponse.statusCode)"
                    ])
                    errorResult(httpError)
                    return
                }
            }
            
            guard let responseData = data else {
                errorResult(NSError(domain: "EmptyResponse", code: -2))
                return
            }
            
            successResult(responseData)
        }.resume()
    }
    
    /// Check if URL matches the features path pattern
    private func matchesFeaturesPattern(_ urlString: String) -> Bool {
        guard let pattern = featuresPathPattern else { return false }
        let range = NSRange(urlString.startIndex..., in: urlString)
        return pattern.firstMatch(in: urlString, options: [], range: range) != nil
    }
}
