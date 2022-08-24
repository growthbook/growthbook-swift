import Foundation

/// Feature Evaluator Class
///
/// Takes Context and Feature Key
///
/// Returns Calculated Feature Result against that key
class FeatureEvaluator {

    /// Takes Context and Feature Key
    ///
    /// Returns Calculated Feature Result against that key
    func evaluateFeature(context: Context, featureKey: String) -> FeatureResult {

        guard let targetFeature: Feature = context.features[featureKey] else {
            return prepareResult(value: JSON.null, source: FeatureSource.unknownFeature)
        }

        // Loop through the feature rules (if any)
        if let rules = targetFeature.rules, rules.count > 0 {

            for rule in rules {

                // If the rule has a condition and it evaluates to false, skip this rule and continue to the next one
                if let condition = rule.condition {
                    guard ConditionEvaluator().isEvalCondition(attributes: context.attributes, conditionObj: condition) else { continue }
                }

                // If rule.force is set
                if let force = rule.force {
                    // If rule.coverage is set
                    if let coverage = rule.coverage {

                        let key = rule.hashAttribute ?? Constants.idAttributeKey
                        // Get the user hash value (context.attributes[rule.hashAttribute || "id"]) and if empty, skip the rule
                        guard let attributeValue = context.attributes.dictionaryValue[key]?.stringValue,
                              attributeValue.isEmpty == false
                        else {
                            continue
                        }

                        // Compute a hash using the Fowler–Noll–Vo algorithm (specifically fnv32-1a)
                        let hashFNV = Utils.shared.hash(data: attributeValue + featureKey)
                        // If the hash is greater than rule.coverage, skip the rule
                        if hashFNV > coverage {
                            continue
                        }

                    }

                    // Return (value = forced value, source = force)
                    return prepareResult(value: force, source: FeatureSource.force)
                } else {
                    // Otherwise, convert the rule to an Experiment object
                    let exp = Experiment(key: rule.key ?? featureKey,
                                         variations: rule.variations ?? [],
                                         namespace: rule.namespace,
                                         hashAttribute: rule.hashAttribute,
                                         weights: rule.weights,
                                         coverage: rule.coverage)

                    // Run the experiment.
                    let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: exp)
                    guard result.inExperiment else {
                        // If result.inExperiment is false, skip this rule and continue to the next one.
                        continue
                    }
                    return prepareResult(value: result.value, source: FeatureSource.experiment, experiment: exp, result: result)
                }

            }

        }

        // Return (value = defaultValue or null, source = defaultValue)
        let defaultValue = targetFeature.defaultValue ?? JSON.null
        return prepareResult(value: defaultValue, source: FeatureSource.defaultValue)
    }

    /// This is a helper method to create a FeatureResult object.
    ///
    /// Besides the passed-in arguments, there are two derived values - on and off, which are just the value cast to booleans.
    private func prepareResult(value: JSON?, source: FeatureSource, experiment: Experiment? = nil, result: ExperimentResult? = nil) -> FeatureResult {
        var isFalse = false
        if let value = value {
            isFalse = value.stringValue == "false" || value.stringValue.isEmpty || value.stringValue == "0"
        }
        return FeatureResult(value: value, isOn: !isFalse, source: source.rawValue, experiment: experiment, result: result)
    }
}
