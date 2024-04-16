import Foundation

/// Network Dispatcher Protocol for API Consumption
///
/// Implement this protocol to define specific implementation for Network Calls - to be made by SDK
@objc public protocol NetworkProtocol: AnyObject {
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
    func consumePOSTRequest(url: String, params: [String : Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
}

class CoreNetworkClient: NetworkProtocol {
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        guard let url = URL(string: url) else { return }

        let request = URLSession.shared.dataTask(with: url) {(data: Data?, response: URLResponse?, error: Error?) in
            guard let data = data else { return }
            if let error = error {
                errorResult(error)
            }
            successResult(data)
        }
        request.resume()
    }
    
    func consumePOSTRequest(url: String, params: [String: Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        guard let url = URL(string: url) else { return }
        
        let session = URLSession.shared
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: params, options: .prettyPrinted)
        } catch let error {
            errorResult(error)
        }
        
        let task = session.dataTask(with: request) { data, response, error in
            if let error = error {
                errorResult(error)
            }
            guard let responseData = data else { return }
            successResult(responseData)
        }
        task.resume()
    }
}
