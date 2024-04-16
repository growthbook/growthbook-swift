import Foundation

struct RemoteEvalParams: Decodable {
    let attributes: JSON?
    let forcedFeatures: JSON?
    let forcedVariations: JSON?
}
