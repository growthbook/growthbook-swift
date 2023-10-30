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
    func evaluateFeature(context: Context, featureKey: String, attributeOverrides: JSON) -> FeatureResult {

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
                
                // If there are filters for who is included
                if let filters = rule.filters {
                    if isFilteredOut(filters: filters, attributeOverrides: attributeOverrides, context: context) {
                        print("Skip rule because of filters")
                        continue
                    }
                }

                // If rule.force is set
                if let force = rule.force {
                    
                    if !isIncludedInRollout(seed: rule.seed ?? "", hashAttribute: rule.hashAttribute, range: rule.range, coverage: rule.coverage, hashVersion: rule.hashVersion, attributeOverrides: attributeOverrides, context: context) {
                        print("Skip rule because user not included in rollout")
                    } 
                    
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
                        let hashFNV = Utils.shared.hash(seed: featureKey, value: attributeValue, version: 1.0) ?? 0.0
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
                                         coverage: rule.coverage,
                                         ranges: rule.ranges,
                                         meta: rule.meta,
                                         filters: rule.filters,
                                         seed: rule.seed,
                                         name: rule.name,
                                         phase: rule.phase)

                    // If there are filters for who is included
                    if let filters = exp.filters {
                        if isFilteredOut(filters: filters, attributeOverrides: attributeOverrides, context: context) {
                            print("Skip because of filters")
                            continue
                        }
                    }
                    
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
    
    ///Returns tuple out of 2 elements: the attribute itself an its hash value
    private func getHashAttribute(attr: String?, attributeOverrides: JSON, context: Context) -> (hashAttribute: String, hashValue: String) {
        let hashAttribute = attr ?? "id"
        var hashValue = ""
        
        if attributeOverrides[hashAttribute] != .null {
            hashValue = attributeOverrides[hashAttribute].stringValue
        } else if context.attributes[hashAttribute] != .null {
            hashValue = context.attributes[hashAttribute].stringValue
        }
        
        return (hashAttribute, hashValue)
    }
    
    ///Determines if the user is part of a gradual feature rollout.
    private func isIncludedInRollout(seed: String, hashAttribute: String?, range: BucketRange?, coverage: Float?, hashVersion: Float?, attributeOverrides: JSON, context: Context) -> Bool {
        if range == nil, coverage == nil {
            return true
        }
        
        let hashValue = getHashAttribute(attr: hashAttribute, attributeOverrides: attributeOverrides, context: context).hashValue
        
        let hash = Utils.shared.hash(seed: seed, value: hashValue, version: hashVersion ?? 1)
        
        guard let hash = hash else { return false }
        
        if let range = range {
            return Utils.shared.inRange(n: hash, range: range)
        } else if let coverage = coverage {
            return hash <= coverage
        } else {
            return true
        }
    }
    
    ///This is a helper method to evaluate `filters` for both feature flags and experiments.
    private func isFilteredOut(filters: [Filter], attributeOverrides: JSON, context: Context) -> Bool {
        return filters.contains { filter in
            let hashAttribute = getHashAttribute(attr: filter.attribute, attributeOverrides: attributeOverrides, context: context)
            let hashValue = hashAttribute.hashValue
            
            let hash = Utils.shared.hash(seed: filter.seed, value: hashValue, version: filter.hashVersion)
            guard let hashValue = hash else { return true }
            
            return !filter.ranges.contains { r in
                return Utils.shared.inRange(n: hashValue, range: r)
            }
        }
    }

    /// This is a helper method to create a FeatureResult object.
    ///
    /// Besides the passed-in arguments, there are two derived values - on and off, which are just the value cast to booleans.
    private func prepareResult(value: JSON?, source: FeatureSource, experiment: Experiment? = nil, result: ExperimentResult? = nil) -> FeatureResult {
        var isFalse = false
        if let value = value {
            isFalse = value.stringValue == "false" || value.stringValue == "0" || (value.stringValue.isEmpty && value.dictionary == nil && value.array == nil)
        }
        return FeatureResult(value: value, isOn: !isFalse, source: source.rawValue, experiment: experiment, result: result)
    }
}
