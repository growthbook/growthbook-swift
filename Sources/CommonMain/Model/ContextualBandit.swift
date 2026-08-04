import Foundation

/// A single leaf of a `ContextualBanditDefinition`: a targeting `condition` paired with the
/// backend-computed variation `weights` to apply when that condition matches the user.
///
/// Part of the read-only contextual bandit payload — leaves are decoded from the feature API
/// response and never mutated during evaluation.
public struct ContextualBanditContext: Codable {
    /// Identifier of this leaf within the bandit definition. Surfaced on `ExperimentResult` so
    /// exposures can be attributed back to the segment that produced the weights.
    public let leafId: Int?
    /// Targeting condition evaluated against the user's attributes. A `nil` or empty condition
    /// matches every user.
    public let condition: JSON?
    /// Variation weights to apply when this leaf matches. Must align with the experiment's
    /// variation count and, like any weights, sum to 1.
    public let weights: [Float]?

    init(leafId: Int? = nil, condition: JSON? = nil, weights: [Float]? = nil) {
        self.leafId = leafId
        self.condition = condition
        self.weights = weights
    }

    init(json: [String: JSON]) {
        leafId = json["leafId"]?.int
        condition = json["condition"]
        if let weights = json["weights"]?.array {
            self.weights = JSON.convertToArrayFloat(jsonArray: weights)
        } else {
            self.weights = nil
        }
    }
}

/// A contextual bandit definition shipped in the feature payload under `contextualBandits`,
/// keyed by the `contextualBanditRef` a feature rule points at.
///
/// A contextual bandit assigns per-segment variation weights: each `ContextualBanditContext`
/// ("leaf") carries a targeting condition and the weights to use when it matches. The weights
/// themselves are computed on the GrowthBook backend — the SDK only selects the matching leaf
/// and applies its weights before bucketing.
public struct ContextualBanditDefinition: Codable {
    /// Monotonic version of the backend-computed weights, echoed onto `ExperimentResult` so
    /// exposures can be attributed to the weight generation that produced them.
    public let banditVersion: Int?
    /// Ordered leaves. Leaves are evaluated top-to-bottom and the first whose condition matches
    /// the user wins; if none match, the SDK falls back to aggregate/equal weights.
    public let contexts: [ContextualBanditContext]?

    init(banditVersion: Int? = nil, contexts: [ContextualBanditContext]? = nil) {
        self.banditVersion = banditVersion
        self.contexts = contexts
    }

    init(json: [String: JSON]) {
        banditVersion = json["banditVersion"]?.int
        contexts = json["contexts"]?.array?.map { ContextualBanditContext(json: $0.dictionaryValue) }
    }
}

/// The outcome of resolving a `ContextualBanditDefinition` for a given user: the selected leaf and
/// the weights that were applied to the `Experiment`.
///
/// Attached to the experiment during evaluation and, when the user is hash-bucketed into the
/// experiment, copied onto `ExperimentResult` for tracking.
///
/// A `leafId` of `-1` means no leaf matched and the experiment fell back to its aggregate or
/// equal weights.
public struct ContextualBandit: Codable {
    /// Sentinel `leafId` recorded when a definition was found but no leaf matched the user.
    public static let fallbackLeafId = -1

    /// The matched leaf's id, or `-1` when no leaf matched and fallback weights were used.
    public let leafId: Int?
    /// The weights actually applied to the experiment for this user.
    public let variationWeights: [Float]?
    /// The bandit version of the definition that produced these weights.
    public let banditVersion: Int?

    init(leafId: Int?, variationWeights: [Float]?, banditVersion: Int?) {
        self.leafId = leafId
        self.variationWeights = variationWeights
        self.banditVersion = banditVersion
    }
}
