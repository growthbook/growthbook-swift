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
                        fallbackAttribute: (context.options.stickyBucketService != nil && !(rule.disableStickyBucketing ?? false)) ? rule.fallbackAttribute : nil,
                        range: rule.range,
                        coverage: rule.coverage,
                        hashVersion: rule.hashVersion
                    ) {
                        logger.info("Skip rule because user not included in rollout")
                        continue
                    }
                    
                    if let tracks = rule.tracks {
                        tracks.forEach { track in
                            if let experiment = track.experiment, let result = track.result {
                                let experimentIsActive = experiment.isActive ?? true
                                let userInExperiment = result.inExperiment
                                if experimentIsActive && userInExperiment && !ExperimentHelper.shared.isTracked(experiment, result) {
                                    context.options.trackingClosure(experiment, result)
                                    context.options.pluginRegistry.onExperimentViewed(experiment: experiment, result: result, attributes: context.userContext.attributes)
                                }
                            }
                        }
                    }
                    
                    // Return (value = forced value, source = force)
                    
                    let forcedFeatureResult = prepareResult(value: force, source: FeatureSource.force, ruleId: rule.id)
                                        
                    return forcedFeatureResult
                } else {

                    // Contextual bandit rules carry their variations under `contextualVariations`
                    // so that SDKs without bandit support skip the rule entirely. Read them first,
                    // regardless of whether a ref is present.
                    guard let variations = rule.contextualVariations ?? rule.variations else {
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

                    // Resolve the contextual bandit (if any) before bucketing — it overrides the
                    // rule's weights with the backend-computed weights for the user's segment.
                    if let contextualBanditRef = rule.contextualBanditRef {
                        applyContextualBandit(to: exp, ref: contextualBanditRef)
                    }

                    // Run the experiment.
                    let result = ExperimentEvaluator().evaluateExperiment(context: context, experiment: exp, featureId: featureKey)

                    // The bandit is attached before evaluation; keep it only when the user was
                    // actually hash-bucketed in, not force-assigned or filtered out. This keeps the
                    // Experiment exposed on FeatureResult consistent with the ExperimentResult.
                    if exp.contextualBandit != nil && !((result.hashUsed ?? false) && result.inExperiment) {
                        exp.contextualBandit = nil
                    }

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
    
    /// Applies a contextual bandit definition to an experiment before bucketing: selects the leaf
    /// whose condition matches the user and overrides the experiment's weights with that leaf's
    /// weights, recording the selection on `Experiment.contextualBandit`.
    ///
    /// If the reference is missing from the payload the experiment is left untouched, so the rule's
    /// own (aggregate) weights apply. If a definition is present but no leaf matches, a fallback
    /// marker (`ContextualBandit.fallbackLeafId`) is recorded and the experiment's existing or equal
    /// weights are used.
    private func applyContextualBandit(to experiment: Experiment, ref: String) {
        guard let definitionJson = context.globalContext.contextualBandits?.dictionaryValue[ref],
              definitionJson.dictionary != nil else {
            logger.debug("Contextual bandit ref not found in payload, using aggregate weights: \(ref)")
            return
        }

        let definition = ContextualBanditDefinition(json: definitionJson.dictionaryValue)

        if let leaf = selectContextualBanditLeaf(from: definition.contexts) {
            experiment.weights = leaf.weights
            experiment.contextualBandit = ContextualBandit(
                leafId: leaf.leafId,
                variationWeights: leaf.weights,
                banditVersion: definition.banditVersion
            )
            return
        }

        let fallbackWeights = experiment.weights
            ?? Utils.getEqualWeights(numVariations: experiment.variations.count)
        experiment.contextualBandit = ContextualBandit(
            leafId: ContextualBandit.fallbackLeafId,
            variationWeights: fallbackWeights,
            banditVersion: definition.banditVersion
        )
    }

    /// Returns the first leaf whose condition matches the user's attributes, or `nil` if none do.
    /// A leaf with no condition matches every user.
    private func selectContextualBanditLeaf(from contexts: [ContextualBanditContext]?) -> ContextualBanditContext? {
        guard let contexts, !contexts.isEmpty else { return nil }

        return contexts.first { leaf in
            ConditionEvaluator().isEvalCondition(
                attributes: context.userContext.attributes,
                conditionObj: leaf.condition ?? JSON([String: JSON]()),
                savedGroups: context.globalContext.savedGroups
            )
        }
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
