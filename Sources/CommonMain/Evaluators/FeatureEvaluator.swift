import Foundation

/// Feature Evaluator Class
///
/// Takes Context and Feature Key
///
/// Returns Calculated Feature Result against that key
class FeatureEvaluator {

    var context: Context
    var evalContext: FeatureEvalContext?
    var featureKey: String
    var attributeOverrides: JSON
    
    init(context: Context, featureKey: String, attributeOverrides: JSON, evalContext: FeatureEvalContext? = nil) {
        self.context = context
        self.featureKey = featureKey
        self.attributeOverrides = attributeOverrides
        self.evalContext = evalContext ?? FeatureEvalContext(evaluatedFeatures: Set<String>())
    }
    
    /// Takes Context and Feature Key
    ///
    /// Returns Calculated Feature Result against that key
    func evaluateFeature() -> FeatureResult {
        
        if (evalContext?.evaluatedFeatures.contains(featureKey) ?? false) {
            return prepareResult(
                value: .null,
                source: FeatureSource.cyclicPrerequisite
            )
        }
        evalContext?.evaluatedFeatures.insert(featureKey)
        evalContext?.id = featureKey
        
        guard let targetFeature: Feature = context.features[featureKey] else {
            return prepareResult(value: JSON.null, source: FeatureSource.unknownFeature)
        }

        // Loop through the feature rules (if any)
        if let rules = targetFeature.rules, rules.count > 0 {

        ruleLoop: for rule in rules {
                
                if let parentConditions = rule.parentConditions {
                    for parentCondition in parentConditions {
                        let parentResult = FeatureEvaluator(context: context, featureKey: parentCondition.id, attributeOverrides: attributeOverrides, evalContext: evalContext).evaluateFeature()
                        if parentResult.source == FeatureSource.cyclicPrerequisite.rawValue {
                            return prepareResult(
                                value: .null,
                                source: FeatureSource.cyclicPrerequisite
                            )
                        }
                        
                        let evalObjc = JSON(["value": parentResult.value])
                        
                        let evalCondition = ConditionEvaluator().isEvalCondition(
                            attributes: evalObjc,
                            conditionObj: parentCondition.condition, 
                            savedGroups: context.savedGroups
                        )
                        
                        // blocking prerequisite eval failed: feature evaluation fails
                        if !evalCondition {
                            if let _ = parentCondition.gate {
                                print("Feature blocked by prerequisite")
                                return prepareResult(
                                    value: .null,
                                    source: FeatureSource.prerequisite
                                )
                            }
                            // non-blocking prerequisite eval failed: break out of parentConditions loop, jump to the next rule
                            continue ruleLoop
                        }
                    }
                }
                
                // If there are filters for who is included
                if let filters = rule.filters {
                    if Utils.isFilteredOut(filters: filters, context: context, attributeOverrides: attributeOverrides) {
                        print("Skip rule because of filters")
                        continue
                    }
                }

                // If rule.force is set
                if let force = rule.force {
                    // If it's a conditional rule, skip if the condition doesn't pass

                    if let condition = rule.condition, !ConditionEvaluator().isEvalCondition(attributes: getAttributes(), 
                                                                                             conditionObj: condition,
                                                                                             savedGroups: context.savedGroups) {
                        print("Skip rule because of condition ff")
                        continue
                    }
                    
                    
                    
                    if !isIncludedInRollout(seed: rule.seed ?? featureKey,
                                            hashAttribute: rule.hashAttribute,
                                            fallbackAttribute: (context.stickyBucketService != nil && !(rule.disableStickyBucketing ?? true)) ? rule.fallbackAttribute : nil,
                                            range: rule.range,
                                            coverage: rule.coverage,
                                            hashVersion: rule.hashVersion) {
                        print("Skip rule because user not included in rollout")
                        continue
                    }
                    
                    if let tracks = rule.tracks {
                        tracks.forEach { track in
                            if !ExperimentHelper.shared.isTracked(track.experiment, track.result) {
                                context.trackingClosure(track.experiment, track.result)
                            }
                        }
                    }
                    
                    // Ignore coverage if the rule has a range
                    if rule.range == nil {
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
                            let hashFNV = Utils.hash(seed: featureKey, value: attributeValue, version: 1.0) ?? 0.0
                            // If the hash is greater than rule.coverage, skip the rule
                            if hashFNV > coverage {
                                continue ruleLoop
                            }
                            
                        }
                    }

                    // Return (value = forced value, source = force)
                    
                    return prepareResult(value: force, source: FeatureSource.force)
                } else {
                    
                    guard let variations = rule.variations else {
                        continue
                    }
                    
                    // Otherwise, convert the rule to an Experiment object
                    let exp = Experiment(key: rule.key ?? featureKey,
                                         variations: variations,
                                         namespace: rule.namespace,
                                         hashAttribute: rule.hashAttribute,
                                         fallBackAttribute: rule.fallbackAttribute,
                                         hashVersion: rule.hashVersion,
                                         disableStickyBucketing: rule.disableStickyBucketing ?? false,
                                         bucketVersion: rule.bucketVersion,
                                         minBucketVersion: rule.minBucketVersion,
                                         weights: rule.weights,
                                         coverage: rule.coverage,
                                         condition: rule.condition,
                                         ranges: rule.ranges,
                                         meta: rule.meta,
                                         filters: rule.filters,
                                         seed: rule.seed,
                                         name: rule.name,
                                         phase: rule.phase
                                         )
                    
                    // Run the experiment.
                    let result = ExperimentEvaluator(attributeOverrides: attributeOverrides).evaluateExperiment(context: context, experiment: exp)
                    if result.inExperiment && !(result.passthrough ?? false) {
                        // If result.inExperiment is false, skip this rule and continue to the next one.
                        return prepareResult(value: result.value, source: FeatureSource.experiment, experiment: exp, result: result)
                    }
                }
            }
        }

        // Return (value = defaultValue or null, source = defaultValue)
        let defaultValue = targetFeature.defaultValue ?? .null
        return prepareResult(value: defaultValue, source: FeatureSource.defaultValue)
    }    
    
    ///Determines if the user is part of a gradual feature rollout.
    private func isIncludedInRollout(seed: String, hashAttribute: String?, fallbackAttribute: String?, range: BucketRange?, coverage: Float?, hashVersion: Float?) -> Bool {
        if range == nil, coverage == nil {
            return true
        }
        
        if range == nil, coverage == 0 {
            return false
        }
        
        let hashValue = Utils.getHashAttribute(context: context, attr: hashAttribute, fallback: fallbackAttribute, attributeOverrides: attributeOverrides).hashValue
        
        let hash = Utils.hash(seed: seed, value: hashValue, version: hashVersion ?? 1)
        
        guard let hash = hash else { return false }
        
        if let range = range {
            return Utils.inRange(n: hash, range: range)
        } else if let coverage = coverage {
            return hash <= coverage
        } else {
            return true
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
    
    private func getAttributes() -> JSON {
        return (try? context.attributes.merged(with: attributeOverrides)) ?? JSON()
    }
}


extension Dictionary {
    mutating func merge(_ other: [Key: Value]) {
        for (key, value) in other {
            self[key] = value
        }
    }
}

struct FeatureEvalContext {
    var id: String?
    var evaluatedFeatures: Set<String>
}
