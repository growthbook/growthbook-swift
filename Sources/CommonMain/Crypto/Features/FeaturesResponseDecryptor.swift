//
//  FeaturesResponseDecryptor.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

protocol FeaturesResponseDecryptorInterface: Sendable {
    func decrypt(featuresDataModel: FeaturesDataModel) throws -> DecryptedFeaturesDataModel
}

struct FeaturesResponseDecryptor: FeaturesResponseDecryptorInterface {
    private let payloadType: GrowthBookInstance.PayloadType
    private let crypto: CryptoProtocol

    init(payloadType: GrowthBookInstance.PayloadType, crypto: CryptoProtocol) {
        self.payloadType = payloadType
        self.crypto = crypto
    }

    private func parseProbablyEncryptedValue<T: Decodable>(_ savedGroups: ProbablyEncryptedValue<T>?, defaultValue: T) throws -> T {
        switch savedGroups {
        case .none:
            return defaultValue
        case let .encryptedString(encryptedString):
            switch payloadType {
            case .plainText:
                assertionFailure("Should never happen")
                return defaultValue
            case let .ciphered(encryptionKey: encryptionKey), let .remoteEvaluated(encryptionKey: encryptionKey):
                return try crypto.decryptAndDecode(from: encryptedString, using: encryptionKey)
            }
        case let .plain(savedGroups):
            return savedGroups
        }
    }

    func decrypt(featuresDataModel: FeaturesDataModel) throws -> DecryptedFeaturesDataModel {
        try .init(
            dateUpdated: featuresDataModel.dateUpdated,
            features: parseProbablyEncryptedValue(featuresDataModel.features, defaultValue: [:]),
            savedGroups: parseProbablyEncryptedValue(featuresDataModel.savedGroups, defaultValue: .null),
            experiments: parseProbablyEncryptedValue(featuresDataModel.experiments, defaultValue: [])
        )
    }
}
