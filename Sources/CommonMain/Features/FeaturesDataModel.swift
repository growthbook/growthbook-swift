import Foundation

/// Data Object for Feature API Response
@objc class FeaturesDataModel: NSObject, Codable {
    var features: Features?
    var encryptedFeatures: String?
    var dateUpdated: String?
    var savedGroups: JSON?
    var encryptedSavedGroups: String?
    var experiments: [Experiment]?
    var encryptedExperiments: String?
    
    init(features: Features? = nil, encryptedFeatures: String? = nil, dateUpdated: String? = nil, savedGroups: JSON? = nil, encryptedSavedGroups: String? = nil, experiments: [Experiment]? = nil, encryptedExperiments: String? = nil) {
        self.features = features
        self.encryptedFeatures = encryptedFeatures
        self.dateUpdated = dateUpdated
        self.savedGroups = savedGroups
        self.encryptedSavedGroups = encryptedSavedGroups
        self.experiments = experiments
        self.encryptedExperiments = encryptedExperiments
    }
}
