import Foundation

/// Network Dispatcher Protocol for API Consumption
///
/// Implement this protocol to define specific implementation for Network Calls - to be made by SDK
@objc public protocol NetworkProtocol: AnyObject {
    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void)
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
}
