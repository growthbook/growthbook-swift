import Foundation

/// Data Object for Feature API Response
struct FeaturesDataModel: Codable {
    var features: Features?
    var encryptedFeatures: String?
    var dateUpdated: String?
}
