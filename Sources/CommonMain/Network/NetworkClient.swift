import Foundation

/// Network Dispatcher Protocol for API Consumption
///
/// Implement this protocol to define specific implementation for Network Calls - to be made by SDK
@objc public protocol NetworkProtocol: AnyObject {
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
    func consumePOSTRequest(url: String, params: [String : Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
}

class CoreNetworkClient: NetworkProtocol {
    var tokenProvider: (() -> String?)?
    var onTokenExpired: (() -> Void)?
    var defaultHeaders: [String: String]
    
    init(tokenProvider: (() -> String?)? = nil,
         onTokenExpired: (() -> Void)? = nil,
         defaultHeaders: [String: String] = [:]) {
        self.tokenProvider = tokenProvider
        self.onTokenExpired = onTokenExpired
        self.defaultHeaders = defaultHeaders
    }
    
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        perform(url: url, method: "GET", params: nil, successResult: successResult, errorResult: errorResult)
    }
    
    func consumePOSTRequest(url: String, params: [String : Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        perform(url: url, method: "POST", params: params, successResult: successResult, errorResult: errorResult)
    }
    
    private func perform(url: String, method: String, params: [String: Any]?, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        guard let url = URL(string: url) else { return }
        
        var request = URLRequest(url: url)
        request.httpMethod = method
        
        for (key, value) in defaultHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }
        
        if let token = tokenProvider?() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                errorResult(error)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 401 {
                self.onTokenExpired?()
                return
            }
            
            guard let data = data else {
                errorResult(NSError(domain: "EmptyResponse", code: -2))
                return
            }
            
            successResult(data)
        }.resume()
    }
}
