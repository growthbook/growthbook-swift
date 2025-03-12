import Foundation

enum ProbablyEncryptedValue<Value: Decodable> {
    case encryptedString(String)
    case plain(Value)

    init?(_ value: Value?, encrypted encryptedString: String?) {
        switch (value, encryptedString) {
        case (.none, .none):
            return nil
        case let (.some, .some(encryptedString)):
            assertionFailure("Should not have both plain and encrypted. Will prefer encrypted in release build.")
            self = .encryptedString(encryptedString)
        case let (.some(value), .none):
            self = .plain(value)
        case let (.none, .some(encryptedString)):
            self = .encryptedString(encryptedString)
        }
    }
}

/// Data Object for Feature API Response
struct FeaturesDataModel {
    var dateUpdated: String?

    var features: ProbablyEncryptedValue<Features>?
    var savedGroups: ProbablyEncryptedValue<JSON>?
    var experiments: ProbablyEncryptedValue<[Experiment]>?
}

struct DecryptedFeaturesDataModel: Sendable {
    var dateUpdated: String?

    var features: Features
    var savedGroups: JSON
    var experiments: [Experiment]
}

extension FeaturesDataModel: Decodable {
    private enum CodingKeys: CodingKey {
        case features
        case encryptedFeatures
        case dateUpdated
        case savedGroups
        case encryptedSavedGroups
        case experiments
        case encryptedExperiments
    }

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        self.dateUpdated = try container.decodeIfPresent(String.self, forKey: .dateUpdated)

        let plainFeatures = try container.decodeIfPresent(Features.self, forKey: .features)
        let encryptedFeatures = try container.decodeIfPresent(String.self, forKey: .encryptedFeatures)
        self.features = ProbablyEncryptedValue(plainFeatures, encrypted: encryptedFeatures)

        let plainSavedGroups = try container.decodeIfPresent(JSON.self, forKey: .savedGroups)
        let encryptedSavedGroups = try container.decodeIfPresent(String.self, forKey: .encryptedSavedGroups)
        self.savedGroups = ProbablyEncryptedValue(plainSavedGroups, encrypted: encryptedSavedGroups)

        let plainExperiments = try container.decodeIfPresent([Experiment].self, forKey: .experiments)
        let encryptedExperiments = try container.decodeIfPresent(String.self, forKey: .encryptedExperiments)
        self.experiments = ProbablyEncryptedValue(plainExperiments, encrypted: encryptedExperiments)
    }
}
