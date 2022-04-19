import Foundation
import SwiftyJSON

/// Defines a single experiment
@objc public class Experiment: NSObject, Decodable {
    /// The globally unique tracking key for the experiment
    public let key: String
    /// The different variations to choose between
    public let variations: [JSON]
    /// A tuple that contains the namespace identifier, plus a range of coverage for the experiment
    public let namespace: [JSON]?
    /// All users included in the experiment will be forced into the specific variation index
    public let hashAttribute: String?
    /// How to weight traffic between variations. Must add to 1.
    public var weights: [Float]?
    /// If set to false, always return the control (first variation)
    public var isActive: Bool
    /// What percent of users should be included in the experiment (between 0 and 1, inclusive)
    public var coverage: Float?
    /// Optional targeting condition
    public var condition: JSON?
    /// All users included in the experiment will be forced into the specific variation index
    public var force: Int?

    public init(key: String,
         variations: [Any] = [],
         namespace: [Any]? = nil,
         hashAttribute: String? = nil,
         weights: [Float]? = nil,
         isActive: Bool = true,
         coverage: Float? = nil,
         condition: Any? = nil,
         force: Int? = nil) {
        self.key = key
        self.variations = JSON(variations).arrayValue
        if let namespace = namespace {
            self.namespace = JSON(namespace).arrayValue
        } else {
            self.namespace = nil
        }
        self.hashAttribute = hashAttribute
        self.weights = weights
        self.isActive = isActive
        self.coverage = coverage
        if let condition = condition {
            self.condition = JSON(condition)
        }
        self.force = force
    }

    init(key: String,
         variations: [JSON] = [],
         namespace: [JSON]? = nil,
         hashAttribute: String? = nil,
         weights: [Float]? = nil,
         isActive: Bool = true,
         coverage: Float? = nil,
         condition: Condition? = nil,
         force: Int? = nil) {
        self.key = key
        self.variations = variations
        self.namespace = namespace
        self.hashAttribute = hashAttribute
        self.weights = weights
        self.isActive = isActive
        self.coverage = coverage
        self.condition = condition
        self.force = force
    }

    init(json: [String: JSON]) {
        key = json["key"]?.stringValue ?? ""

        variations = json["variations"]?.arrayValue ?? []

        namespace = json["namespace"]?.arrayValue

        hashAttribute = json["hashAttribute"]?.stringValue

        isActive = json["active"]?.boolValue ?? true

        if let weights = json["weights"] {
            self.weights = JSON.convertToArrayFloat(jsonArray: weights.arrayValue)
        }

        coverage = json["coverage"]?.floatValue

        condition = json["condition"]

        force = json["force"]?.intValue
    }
}

/// The result of running an Experiment given a specific Context
@objc public class ExperimentResult: NSObject, Codable {
    /// Whether or not the user is part of the experiment
    public let inExperiment: Bool
    /// The array index of the assigned variation
    public let variationId: Int
    /// The array value of the assigned variation
    public let value: JSON
    /// The user attribute used to assign a variation
    public let hashAttribute: String?
    /// The value of that attribute
    public let valueHash: String?

    init(inExperiment: Bool, variationId: Int, value: JSON, hashAttribute: String? = nil, hashValue: String? = nil) {
        self.inExperiment = inExperiment
        self.variationId = variationId
        self.value = value
        self.hashAttribute = hashAttribute
        self.valueHash = hashValue
    }
}
