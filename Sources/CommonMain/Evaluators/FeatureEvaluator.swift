import Foundation

/// Feature Evaluator Class
///
/// Takes Context and Feature Key
///
/// Returns Calculated Feature Result against that key
class FeatureEvaluator {

    var context: EvalContext
    var featureKey: String
    
    init(context: EvalContext, featureKey: String) {
        self.context = context
        self.featureKey = featureKey
    }
    
    /// Takes Context and Feature Key
    ///
    /// Returns Calculated Feature Result against that key
    func evaluateFeature() -> FeatureResult {
        
        if (context.stackContext.evaluatedFeatures.contains(featureKey)) {
            logger.info("evaluateFeature: circular dependency detected:")
            
            let featureResultWhenCircularDependencyDetected = prepareResult(
                value: .null,
                source: FeatureSource.cyclicPrerequisite
            )
                        
            return featureResultWhenCircularDependencyDetected
        }
        context.stackContext.evaluatedFeatures.insert(featureKey)
        context.stackContext.id = featureKey
        
        defer {
            context.stackContext.evaluatedFeatures.remove(featureKey)
        }
        
        if context.userContext.forcedFeatureValues?.dictionaryValue[featureKey] != nil {
            let value = context.userContext.forcedFeatureValues?[featureKey] ?? "nil"
            logger.info("Global override for forced feature with key: \(featureKey) and value \(value)")
            
            return prepareResult(value: context.userContext.forcedFeatureValues?.dictionaryValue[featureKey], source: FeatureSource.override)
        }
        
        guard let targetFeature: Feature = context.globalContext.features[featureKey] else {
            let emptyFeatureResult = prepareResult(value: JSON.null, source: FeatureSource.unknownFeature)
            
            return emptyFeatureResult
        }

        // Loop through the feature rules (if any)
        if let rules = targetFeature.rules, rules.count > 0 {
            let evaluatedFeatures = Set(context.stackContext.evaluatedFeatures)

            ruleLoop: for rule in rules {
                if let parentConditions = rule.parentConditions {
                    for parentCondition in parentConditions {
                        context.stackContext.evaluatedFeatures = Set(evaluatedFeatures)

                        let parentEvaluator = FeatureEvaluator(
                            context: context,
                            featureKey: parentCondition.id
                        )
                        let parentResult = parentEvaluator.evaluateFeature()
                        // Propagate any sticky bucket assignments from parent evaluation
                        Utils.propagateStickyAssignments(from: parentEvaluator.context, to: context)
                        
                        if parentResult.source == FeatureSource.cyclicPrerequisite.rawValue {
                            let featureResultWhenCircularDependencyDetected =  prepareResult(
                                value: .null,
                                source: FeatureSource.cyclicPrerequisite
                            )
                                                        
                            return featureResultWhenCircularDependencyDetected
                        }
                        
                        let evalObjc = JSON(["value": parentResult.value])
                        
                        let evalCondition = ConditionEvaluator().isEvalCondition(
                            attributes: evalObjc,
                            conditionObj: parentCondition.condition,
                            savedGroups: context.globalContext.savedGroups
                        )
                        
                        // blocking prerequisite eval failed: feature evaluation fails
                        if !evalCondition {
                            if let _ = parentCondition.gate {
                                logger.info("Feature blocked by prerequisite")
                                let featureResultWhenBlockedByPrerequisite =  prepareResult(
                                    value: .null,
                                    source: FeatureSource.prerequisite
                                )
                                                                
                                return featureResultWhenBlockedByPrerequisite
                            }
                            // non-blocking prerequisite eval failed: break out of parentConditions loop, jump to the next rule
                            continue ruleLoop
                        }
                    }
                }
                
                // If there are filters for who is included
                if let filters = rule.filters {
                    if Utils.isFilteredOut(filters: filters, attributes: context.userContext.attributes
                    ) {
                        logger.info("Skip rule because of filters")
                        continue
                    }
                }

                // If rule.force is set
                if let force = rule.force {
                    // If it's a conditional rule, skip if the condition doesn't pass

                    if let condition = rule.condition, !ConditionEvaluator().isEvalCondition(
                        attributes: context.userContext.attributes,
                        conditionObj: condition,
                        savedGroups: context.globalContext.savedGroups
                    ) {
                        continue
                    }
                    
                    if !Utils.isIncludedInRollout(
                        attributes: context.userContext.attributes,
                        seed: rule.seed ?? featureKey,
                        hashAttribute: rule.hashAttribute,
                        fallbackAttribute: (context.options.stickyBucketService != nil && !(rule.disableStickyBucketing ?? true)) ? rule.fallbackAttribute : nil,
                        range: rule.range,
                        coverage: rule.coverage,
                        hashVersion: rule.hashVersion
                    ) {
                        logger.info("Skip rule because user not included in rollout")
                        continue
                    }
                    
                    if let tracks = rule.tracks {
                        tracks.forEach { track in
                            if let experiment = track.result?.experiment, let result = track.result?.experimentResult, !ExperimentHelper.shared.isTracked(experiment, result) {
                                context.options.trackingClosure(experiment, result)
                            }
                        }
                    }
                    
                    // Ignore coverage if the rule has a range
                    if rule.range == nil {
                        // If rule.coverage is set
                        if let coverage = rule.coverage {
                            
                            let key = rule.hashAttribute ?? Constants.idAttributeKey
                            // Get the user hash value (context.attributes[rule.hashAttribute || "id"]) and if empty, skip the rule
                            guard let attributeValue = context.userContext.attributes.dictionaryValue[key]?.stringValue,
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
                    
                    let forcedFeatureResult = prepareResult(value: force, source: FeatureSource.force, ruleId: rule.id)
                                        
                    return forcedFeatureResult
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
                    let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: exp, featureId: featureKey)
                    if result.inExperiment && !(result.passthrough ?? false) {
                        // If result.inExperiment is false, skip this rule and continue to the next one.
                        let experimentFeatureResult =  prepareResult(value: result.value, source: FeatureSource.experiment, experiment: exp, result: result, ruleId: rule.id)
                                                
                        return experimentFeatureResult
                    }
                }
            }
        }

        // Return (value = defaultValue or null, source = defaultValue)
        let defaultValue = targetFeature.defaultValue ?? .null
        let defaultFeatureResult = prepareResult(value: defaultValue, source: FeatureSource.defaultValue)
                
        return defaultFeatureResult
    }
    
    /// This is a helper method to create a FeatureResult object.
    ///
    /// Besides the passed-in arguments, there are two derived values - on and off, which are just the value cast to booleans.
    private func prepareResult(value: JSON?, source: FeatureSource, experiment: Experiment? = nil, result: ExperimentResult? = nil, ruleId: String? = "") -> FeatureResult {
        var isFalse = false
        if let value = value {
            isFalse = value.stringValue == "false" || value.stringValue == "0" || (value.stringValue.isEmpty && value.dictionary == nil && value.array == nil)
        }
        return FeatureResult(value: value, isOn: !isFalse, source: source.rawValue, experiment: experiment, result: result, ruleId: ruleId)
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
