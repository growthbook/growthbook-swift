import Foundation


/// DataSource for Feature API
class FeaturesDataSource {
    let dispatcher: GrowthBookNetworkProtocol
    private let payloadType: GrowthBookInstance.PayloadType
    private let featuresURL: URL
    private let remoteEvaluatedFeaturesURL: URL
    let remoteEvaluationParameters: RemoteEvalParams?
    let featuresResponseDecryptor: FeaturesResponseDecryptorInterface

    init(
        payloadType: GrowthBookInstance.PayloadType,
        featuresURL: URL,
        remoteEvaluatedFeaturesURL: URL,
        remoteEvaluationParameters: RemoteEvalParams?,
        encryptionKey: String? = nil,
        dispatcher: GrowthBookNetworkProtocol = GrowthBookNetworkClient(),
        featuresResponseDecryptor: FeaturesResponseDecryptorInterface
    )
    {
        self.payloadType = payloadType
        self.featuresURL = featuresURL
        self.remoteEvaluatedFeaturesURL = remoteEvaluatedFeaturesURL
        self.remoteEvaluationParameters = remoteEvaluationParameters
        self.dispatcher = dispatcher
        self.featuresResponseDecryptor = featuresResponseDecryptor
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

//    private func parseProbablyEncryptedValue<T: Decodable>(_ savedGroups: ProbablyEncryptedValue<T>, defaultValue: T) throws -> T {
//        switch savedGroups {
//        case let .encryptedString(encryptedString):
//            switch instance.payloadType {
//            case .plainText:
//                assertionFailure("Should never happen")
//                return defaultValue
//            case let .ciphered(encryptionKey: encryptionKey), let .remoteEvaluated(encryptionKey: encryptionKey):
//                return try crypto.decryptAndDecode(from: encryptedString, using: encryptionKey)
//            }
//        case let .plain(savedGroups):
//            return savedGroups
//        }
//    }
//
//    func decrypt(featuresDataModel: FeaturesDataModel) throws -> DecryptedFeaturesDataModel {
//        try .init(
//            dateUpdated: featuresDataModel.dateUpdated,
//            features: parseProbablyEncryptedValue(featuresDataModel.features, defaultValue: [:]),
//            savedGroups: parseProbablyEncryptedValue(featuresDataModel.savedGroups, defaultValue: .null),
//            experiments: parseProbablyEncryptedValue(featuresDataModel.experiments, defaultValue: [])
//        )
//    }

    static func handleResponse(
        _ result: Result<GrowthBookNetworkResponse, Error>,
        featuresResponseDecryptor: FeaturesResponseDecryptorInterface
    ) -> Result<DecryptedFeaturesDataModel, Error>
    {
        if case .failure(let error) = result {
            return .failure(error)
        }

        let reposnse = try! result.get()

        let jsonPetitions: FeaturesDataModel

        do {
            jsonPetitions = try JSONDecoder().decode(FeaturesDataModel.self, from: reposnse.data)
        } catch {
            return .failure(error)
        }

        let decrypted: DecryptedFeaturesDataModel
        do {
            decrypted = try featuresResponseDecryptor.decrypt(featuresDataModel: jsonPetitions)
        } catch {
            return .failure(error)
        }

        return .success(decrypted)
    }

    func fetchFeatures(fetchResult: @escaping @Sendable (Result<DecryptedFeaturesDataModel, Error>) -> Void) {
        let urlRequest: URLRequest
        do {
            urlRequest = try buildURLRequest()
        } catch {
            return fetchResult(.failure(error))
        }

        dispatcher.consumeRequest(urlRequest: urlRequest) { [featuresResponseDecryptor] result in
            let featuresDataModelResult = Self.handleResponse(result, featuresResponseDecryptor: featuresResponseDecryptor)
            fetchResult(featuresDataModelResult)
        }
    }

    /// Executes API Call to fetch features and send data for remote eval
    func fetchRemoteEvaluatedFeatures(apiURL: URL, remoteEvaluationParameters: RemoteEvalParams?, fetchResult: @Sendable @escaping (Result<DecryptedFeaturesDataModel, Error>) -> Void) {
        var urlRequest = URLRequest(url: apiURL)
        urlRequest.httpMethod = "POST"

        urlRequest.addValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.addValue("application/json", forHTTPHeaderField: "Accept")

        do {
            urlRequest.httpBody = try remoteEvaluationParameters.map(JSONEncoder().encode)
        } catch {
            return fetchResult(.failure(error))
        }

        dispatcher.consumeRequest(urlRequest: urlRequest) { [featuresResponseDecryptor] result in
            let featuresDataModelResult = Self.handleResponse(result, featuresResponseDecryptor: featuresResponseDecryptor)
            fetchResult(featuresDataModelResult)
        }
    }
}
