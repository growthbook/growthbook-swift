import Foundation

public struct GrowthBookNetworkResponse: Sendable {
    var httpURLResponse: HTTPURLResponse
    var data: Data
}

/// Network Dispatcher Protocol for API Consumption
///
/// Implement this protocol to define specific implementation for Network Calls - to be made by SDK
public protocol GrowthBookNetworkProtocol: AnyObject, Sendable {
    func consumeRequest(urlRequest: URLRequest, completion: @escaping @Sendable (Result<GrowthBookNetworkResponse, Swift.Error>) -> Void)
}


public final class GrowthBookNetworkClient: GrowthBookNetworkProtocol {

    private let urlSession: URLSession

    public init(urlSession: URLSession = .shared) {
        self.urlSession = urlSession
    }

    public func consumeRequest(urlRequest: URLRequest, completion: @escaping @Sendable (Result<GrowthBookNetworkResponse, Swift.Error>) -> Void) {
        let dataTask = urlSession.dataTask(with: urlRequest) { (data: Data?, urlResponse: URLResponse?, error: Swift.Error?) in
            guard error == nil else {
                return completion(.failure(ResponseError.urlRequestError(error!, response: urlResponse, payload: data)))
            }

            guard let data else {
                return completion(.failure(ResponseError.noData(response: urlResponse)))
            }

            guard let httpURLResponse = urlResponse as? HTTPURLResponse else {
                return completion(.failure(ResponseError.responseInNotHTTPURLResponse(response: urlResponse, payload: data)))
            }

            guard 200..<300 ~= httpURLResponse.statusCode else {
                return completion(.failure(ResponseError.invalidResponseStatusCode(code: httpURLResponse.statusCode, response: httpURLResponse, payload: data)))
            }

            completion(.success(.init(httpURLResponse: httpURLResponse, data: data)))
        }

        dataTask.resume()
    }

}

extension GrowthBookNetworkClient {
    struct ResponseError: Swift.Error, Sendable {
        enum ErrorType: Sendable {
            case urlRequestError(Swift.Error)
            case noData
            case responseInNotHTTPURLResponse
            case invalidResponseStatusCode(code: Int)
        }

        let type: ErrorType
        let response: URLResponse?
        let payload: Data?

        var underlyingError: Swift.Error? {
            switch type {
            case .urlRequestError(let error):
                return error
            case .noData, .responseInNotHTTPURLResponse, .invalidResponseStatusCode:
                return .none
            }
        }

        static func urlRequestError(_ error: Swift.Error, response: URLResponse?, payload: Data?) -> ResponseError {
            .init(type: .urlRequestError(error), response: response, payload: payload)
        }

        static func noData(response: URLResponse?) -> ResponseError {
            .init(type: .noData, response: response, payload: nil)
        }

        static func responseInNotHTTPURLResponse(response: URLResponse?, payload: Data?) -> ResponseError {
            .init(type: .responseInNotHTTPURLResponse, response: response, payload: payload)
        }

        static func invalidResponseStatusCode(code: Int, response: HTTPURLResponse, payload: Data?) -> ResponseError {
            .init(type: .invalidResponseStatusCode(code: code), response: response, payload: payload)
        }
    }
}
