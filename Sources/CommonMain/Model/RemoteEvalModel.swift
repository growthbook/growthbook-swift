import Foundation

public struct RemoteEvalParams: Encodable, Decodable, Sendable {
    let attributes: JSON?
    let forcedFeatures: JSON?
    let forcedVariations: JSON?
}
