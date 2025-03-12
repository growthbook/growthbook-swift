//
//  FeaturesDataParser.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 3/3/25.
//

import Foundation

protocol FeaturesDataParserInterface: Sendable {
    func parseFeaturesData(_ data: Data) throws -> DecryptedFeaturesDataModel
}

struct FeaturesDataParser: FeaturesDataParserInterface {
    private let featuresResponseDecryptor: FeaturesResponseDecryptorInterface
    private let decoder: @Sendable (Data) throws -> FeaturesDataModel

    init<Decoder: TopLevelDecoder>(
        featuresResponseDecryptor: FeaturesResponseDecryptorInterface,
        decoder: Decoder
    ) where Decoder.Input == Data
    {
        self.featuresResponseDecryptor = featuresResponseDecryptor
        self.decoder = { try decoder.decode(FeaturesDataModel.self, from: $0) }
    }

    func parseFeaturesData(_ data: Data) throws -> DecryptedFeaturesDataModel {

        let jsonPetitions: FeaturesDataModel = try decoder(data)

        let decryptedFeaturesModel = try featuresResponseDecryptor.decrypt(featuresDataModel: jsonPetitions)

        return decryptedFeaturesModel
    }
}

extension FeaturesDataParser {
    static func build<Decoder: TopLevelDecoder>(
        payloadType: GrowthBookInstance.PayloadType,
        crypto: CryptoProtocol = Crypto(),
        decoder: Decoder = JSONDecoder()
    ) -> Self where Decoder.Input == Data
    {
        .init(
            featuresResponseDecryptor: FeaturesResponseDecryptor(payloadType: payloadType, crypto: crypto),
            decoder: decoder
        )
    }
}
