//
//  File.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

struct FeaturesModelResponse: Sendable {
    let decryptedFeaturesDataModel: DecryptedFeaturesDataModel
    let expiresInSeconds: Int
}

protocol FeaturesModelFetcherInterface: Sendable {
    func fetchFeatures(fetchResult callback: @escaping @Sendable (Result<FeaturesModelResponse, Error>) -> Void)
}

struct FeaturesModelFetcher: Sendable {
    private let payloadType: GrowthBookInstance.PayloadType
    private let featuresURL: URL
    private let remoteEvaluatedFeaturesURL: URL
    private let remoteEvaluationParameters: RemoteEvalParams?
    private let networkDispatcher: GrowthBookNetworkProtocol
    private let featuresDataParser: FeaturesDataParserInterface

    init(
        payloadType: GrowthBookInstance.PayloadType,
        featuresURL: URL,
        remoteEvaluatedFeaturesURL: URL,
        remoteEvaluationParameters: RemoteEvalParams?,
        networkDispatcher: GrowthBookNetworkProtocol,
        featuresDataParser: FeaturesDataParserInterface
    )
    {
        self.payloadType = payloadType
        self.featuresURL = featuresURL
        self.remoteEvaluatedFeaturesURL = remoteEvaluatedFeaturesURL
        self.remoteEvaluationParameters = remoteEvaluationParameters
        self.networkDispatcher = networkDispatcher
        self.featuresDataParser = featuresDataParser
    }

    private func buildURLRequest() throws -> URLRequest {
        var urlRequest: URLRequest
        switch payloadType {
        case .plainText, .ciphered:
            urlRequest = URLRequest(url: featuresURL)
        case .remoteEvaluated:
            urlRequest = URLRequest(url: remoteEvaluatedFeaturesURL)
            urlRequest.httpMethod = "POST"
            urlRequest.httpBody = try remoteEvaluationParameters.map(JSONEncoder().encode)

            urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        return urlRequest
    }
}

extension FeaturesModelFetcher: FeaturesModelFetcherInterface {
    func fetchFeatures(fetchResult callback: @escaping @Sendable (Result<FeaturesModelResponse, Error>) -> Void) {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildURLRequest()
        } catch {
            return callback(.failure(error))
        }

        logger.debug("Fetching features...")
        networkDispatcher.consumeRequest(urlRequest: urlRequest) { [featuresDataParser] result in
            let result: Result<FeaturesModelResponse, Error> = result.tryMap { response in
                .init(
                    decryptedFeaturesDataModel: try featuresDataParser.parseFeaturesData(response.data),
                    expiresInSeconds: response.httpURLResponse.responseExpiresIn()
                )
            }

            switch result {
            case .success:
                logger.debug("Successfully fetched features.")
            case let .failure(error):
                logger.error("Failed to fetch features: \(error).")
            }
            callback(result)
        }
    }
}

extension DateFormatter {
    fileprivate static let httpHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EE, dd MMM yyyy HH:mm:ss GMT"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

extension Result {
    fileprivate func tryMap<Output>(_ transform: (Success) throws -> Output) -> Result<Output, Error> {
        switch self {
        case .success(let value):
            do {
                return .success(try transform(value))
            } catch {
                return .failure(error)
            }
        case .failure(let error):
            return .failure(error)
        }
    }
}

extension HTTPURLResponse {
    fileprivate func responseExpiresIn() -> Int {
        let expiresIn = (sMaxAgeHeaderValue() ?? maxAgeHeaderValue()) - ageHeaderValue()
        guard expiresIn == 0 else { return expiresIn }

        return Int(expiresHeaderValue()?.timeIntervalSinceNow ?? 0.0)
    }

    private func _value(forHTTPHeaderField field: String) -> String? {
        if #available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, visionOS 1.0, *) {
            value(forHTTPHeaderField: field)
        } else {
            allHeaderFields["Age"] as? String
        }
    }

    private func ageHeaderValue() -> Int {
        _value(forHTTPHeaderField: "Age").flatMap(Int.init(_:)) ?? 0
    }

    private func expiresHeaderValue() -> Date? {
        _value(forHTTPHeaderField: "Expires").flatMap(DateFormatter.httpHeaderDateFormatter.date(from:))
    }

    private func sMaxAgeHeaderValue() -> Int? {
        guard let cacheControl = _value(forHTTPHeaderField: "Cache-Control") else { return nil }

        let keyValues: [String: String] = cacheControl
            .split(separator: ",")
            .filter { $0.contains("=") }
            .reduce(into: [String: String]()) { accum, string in
                let keyValues = string.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                guard keyValues.count == 2 else { return }
                accum[keyValues[0]] = keyValues[1]
            }

        let maxAge = keyValues["s-maxage"].flatMap(Int.init(_:))

        return maxAge
    }

    private func maxAgeHeaderValue() -> Int {
        guard let cacheControl = _value(forHTTPHeaderField: "Cache-Control") else { return 0 }

        let keyValues: [String: String] = cacheControl
            .split(separator: ",")
            .filter { $0.contains("=") }
            .reduce(into: [String: String]()) { accum, string in
                let keyValues = string.split(separator: "=").map { $0.trimmingCharacters(in: .whitespaces) }
                guard keyValues.count == 2 else { return }
                accum[keyValues[0]] = keyValues[1]
            }

        let maxAge = keyValues["max-age"].flatMap(Int.init(_:))

        return maxAge ?? 0
    }
}
