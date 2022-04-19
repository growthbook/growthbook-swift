import Foundation
import SwiftyJSON

/// Experiment Evaluator Class
/// 
/// Takes Context & Experiment & returns Experiment Result
public class ExperimentEvaluator {

    /// Takes Context & Experiment & returns Experiment Result
    func evaluateExperiment(context: Context, experiment: Experiment) -> ExperimentResult {
        // If experiment.variations has fewer than 2 variations, return immediately (not in experiment, variationId 0)
        //
        // If context.enabled is false, return immediately (not in experiment, variationId 0)
        if experiment.variations.count < 2 || !context.isEnabled {
            return getExperimentResult(gbContext: context, experiment: experiment)
        }

        // If context.forcedVariations[experiment.trackingKey] is defined, return immediately (not in experiment, forced variation)
        if let forcedVariation = context.forcedVariations?.dictionaryValue[experiment.key] {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forcedVariation.intValue)
        }

        // If experiment.action is set to false, return immediately (not in experiment, variationId 0)
        if !experiment.isActive {
            return getExperimentResult(gbContext: context, experiment: experiment)
        }

        // Get the user hash attribute and value (context.attributes[experiment.hashAttribute || "id"]) and if empty, return immediately (not in experiment, variationId 0)
        guard let attributeValue = context.attributes.dictionaryValue[experiment.hashAttribute ?? Constants.idAttributeKey]?.stringValue,
              attributeValue.isEmpty == false
        else {
            return getExperimentResult(gbContext: context, experiment: experiment)
        }

        // If experiment.namespace is set, check if hash value is included in the range and if not, return immediately (not in experiment, variationId 0)
        if let namespaceExperiment = experiment.namespace {
            let namespace = Utils.shared.getGBNameSpace(namespace: namespaceExperiment)
            if let namespace = namespace, !Utils.shared.inNamespace(userId: attributeValue, namespace: namespace) {
                return getExperimentResult(gbContext: context, experiment: experiment)
            }
        }

        // If experiment.condition is set and the condition evaluates to false, return immediately (not in experiment, variationId 0)
        if let condition = experiment.condition {
            if !ConditionEvaluator().isEvalCondition(attributes: context.attributes, conditionObj: condition) {
                return getExperimentResult(gbContext: context, experiment: experiment)
            }
        }

        // Default variation weights and coverage if not specified
        if experiment.weights == nil {
            // Default weights to an even split between all variations
            experiment.weights = Utils.shared.getEqualWeights(numVariations: experiment.variations.count)
        }

        // Default coverage to 1 (100%)
        let coverage = experiment.coverage ?? 1.0
        experiment.coverage = coverage

        // Calculate bucket ranges for the variations
        // Convert weights/coverage to ranges
        var bucketRange: [BucketRange] = []
        if let coverage = experiment.coverage, let weights = experiment.weights {
            bucketRange = Utils.shared.getBucketRanges(numVariations: experiment.variations.count, coverage: coverage, weights: weights)
        }

        let hash = Utils.shared.hash(data: attributeValue + experiment.key)
        let assigned = Utils.shared.chooseVariation(n: hash, ranges: bucketRange)

        // If not assigned a variation (assigned === -1), return immediately (not in experiment, variationId 0)
        if assigned == -1 {
            return getExperimentResult(gbContext: context, experiment: experiment)
        }

        // If experiment.force is set, return immediately (not in experiment, variationId experiment.force)
        if let forceExp = experiment.force {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forceExp, inExperiment: false)
        }

        // If context.qaMode is true, return immediately (not in experiment, variationId 0)
        if context.isQaMode {
            return getExperimentResult(gbContext: context, experiment: experiment)
        }

        // Fire context.trackingClosure if set and the combination of hashAttribute, hashValue, experiment.key, and variationId has not been tracked before
        let result = getExperimentResult(gbContext: context, experiment: experiment, variationIndex: assigned, inExperiment: true)
        context.trackingClosure(experiment, result)

        // Return (in experiment, assigned variation)
        return result
    }

    /// This is a helper method to create an ExperimentResult object.
    private func getExperimentResult(gbContext: Context, experiment: Experiment, variationIndex: Int = 0, inExperiment: Bool = false) -> ExperimentResult {
        var targetVariationIndex = variationIndex

        // Check whether variationIndex lies within bounds of variations size
        if targetVariationIndex < 0 || targetVariationIndex >= experiment.variations.count {
            // Set to 0
            targetVariationIndex = 0
        }

        var targetValue = JSON(0)

        // check whether variations are non empty - then only query array against index
        if !experiment.variations.isEmpty {
            targetValue = experiment.variations[targetVariationIndex]
        }

        // Hash Attribute - used for Experiment Calculations
        let hashAttribute = experiment.hashAttribute ?? Constants.idAttributeKey
        // Hash Value against hash attribute
        let hashValue = gbContext.attributes.dictionaryValue[hashAttribute]?.stringValue ?? ""

        return ExperimentResult(inExperiment: inExperiment,
                                variationId: targetVariationIndex,
                                value: targetValue,
                                hashAttribute: hashAttribute,
                                hashValue: hashValue)
    }

}
