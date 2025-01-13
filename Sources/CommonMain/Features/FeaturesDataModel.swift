import Foundation

/// Data Object for Feature API Response
struct FeaturesDataModel: Codable {
    var features: Features?
    var encryptedFeatures: String?
    var dateUpdated: String?
    var savedGroups: JSON?
    var encryptedSavedGroups: String?
    var experiments: [Experiment]?
    var encryptedExperiments: String?
}
