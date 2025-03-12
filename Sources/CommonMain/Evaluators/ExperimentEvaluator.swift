import Foundation

/// Experiment Evaluator Class
/// 
/// Takes Context & Experiment & returns Experiment Result
class ExperimentEvaluator {
    
    /// Takes Context & Experiment & returns Experiment Result
    func evaluateExperiment(context: EvalContext, experiment: Experiment, featureId: String? = nil) -> ExperimentResult {
        // If experiment.variations has fewer than 2 variations, return immediately (not in experiment, variationId 0)
        //
        // If context.enabled is false, return immediately (not in experiment, variationId 0)
        if experiment.variations.count < 2 || !context.options.isEnabled {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }
        
        // If context.forcedVariations[experiment.trackingKey] is defined, return immediately (not in experiment, forced variation)
        if let forcedVariation = context.userContext.forcedVariations?.dictionaryValue[experiment.key] {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forcedVariation.intValue, hashUsed: false, featureId: featureId)
        }
        
        // If experiment.action is set to false, return immediately (not in experiment, variationId 0)
        if let isActive = experiment.isActive, !isActive {
            // TODO: check status == draft scenario
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }
        
        var fallback: String? = nil
        if (isStickyBucketetingEnabledForExperimet(context: context, experiment: experiment)) {
            fallback = experiment.fallbackAttribute
        }
        
        let (hashAttribute, hashValue) = Utils.getHashAttribute(attr: experiment.hashAttribute, fallback: fallback, attributes: context.userContext.attributes)

        if hashValue.isEmpty {
            logger.info("Skip because missing hashAttribute")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }
        var assigned = -1
        var foundStickyBucket = false
        var stickyBucketVersionIsBlocked = false
        
        if isStickyBucketetingEnabledForExperimet(context: context, experiment: experiment) {
            let (variation, versionIsBlocked) = Utils.getStickyBucketVariation(context: context,
                                                                               experimentKey: experiment.key,
                                                                               experimentBucketVersion: experiment.bucketVersion ?? 0,
                                                                               minExperimentBucketVersion: experiment.minBucketVersion ?? 0,
                                                                               meta: experiment.meta ?? [],
                                                                               expFallBackAttribute: experiment.fallbackAttribute,
                                                                               expHashAttribute: experiment.hashAttribute)
            
            foundStickyBucket = variation >= 0;
            assigned = variation
            stickyBucketVersionIsBlocked = versionIsBlocked ?? false
        }
        
        // Some checks are not needed if we already have a sticky bucket
        if !foundStickyBucket {
            if let filters = experiment.filters {
                if Utils.isFilteredOut(filters: filters, attributes: context.userContext.attributes) {
                    return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
                }
            } else if let namespaceExperiment = experiment.namespace,
                      let namespace = Utils.getGBNameSpace(namespace: namespaceExperiment),
                      !Utils.inNamespace(userId: hashValue, namespace: namespace) {
                logger.info("Skip because of namespace")
                return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
            }
            //TODO: check what is include
            
            // If experiment.condition is set and the condition evaluates to false, return immediately (not in experiment, variationId 0)
            if let condition = experiment.condition {
                if !ConditionEvaluator().isEvalCondition(attributes: context.userContext.attributes, conditionObj: condition, savedGroups: context.globalContext.savedGroups) {
                    return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
                }
            }
            
            if let parentConditions = experiment.parentConditions {
                for parentCondition in parentConditions {
                    
                    // TODO: option is to not pass attributeOverrides
                    let parentResult = FeatureEvaluator(context: context, featureKey: parentCondition.id).evaluateFeature()
                    
                    if parentResult.source == FeatureSource.cyclicPrerequisite.rawValue {
                        return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
                    }
                    
                    let evalObj = ["value": parentResult.value]
                    let evalCondition = ConditionEvaluator().isEvalCondition(
                        attributes: JSON(evalObj),
                        conditionObj: parentCondition.condition, 
                        savedGroups: context.globalContext.savedGroups
                    )
                    
                    // blocking prerequisite eval failed: feature evaluation fails
                    if !evalCondition {
                        return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
                    }
                }
            }
        }
        
        let hash = Utils.hash(seed: experiment.seed ?? experiment.key, value: hashValue, version: experiment.hashVersion ?? 1)
        
        guard let hash = hash else {
            logger.info("Skip because of invalid hash version")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }
        
        if !foundStickyBucket {
            let ranges = experiment.ranges ?? Utils.getBucketRanges(numVariations: experiment.variations.count, coverage: experiment.coverage ?? 1, weights: experiment.weights)
            assigned = Utils.chooseVariation(n: hash, ranges: ranges)
        }
        
        if stickyBucketVersionIsBlocked {
            logger.info("Skip because sticky bucket version is blocked")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId, bucket: nil, stickyBucketUsed: true)
        }
        
        // If not assigned a variation (assigned === -1), return immediately (not in experiment, variationId 0)
        if assigned < 0 {
            logger.info("Skip because of coverage")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }

        // If experiment.force is set, return immediately (not in experiment, variationId experiment.force)
        if let forceExp = experiment.force {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forceExp, hashUsed: false, featureId: featureId)
        }

        // If context.qaMode is true, return immediately (not in experiment, variationId 0)
        if context.options.isQaMode {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, featureId: featureId)
        }
        
        let result = getExperimentResult(gbContext: context, experiment: experiment, variationIndex: assigned, hashUsed: true, featureId: featureId, bucket: hash, stickyBucketUsed: foundStickyBucket)
        logger.info("ExperimentResult: \(result)")
        if isStickyBucketetingEnabledForExperimet(context: context, experiment: experiment) {
            let (key, doc, changed) = Utils.generateStickyBucketAssignmentDoc(context: context,
                                                                        attributeName: hashAttribute,
                                                                        attributeValue: hashValue,
                                                                        assignments: [Utils.getStickyBucketExperimentKey(experiment.key,
                                                                                                                   experiment.bucketVersion ?? 0): result.key])
            if changed {
                // User context is created for each evaluation.
                // Changes here don't propagate to the Sticky bucket storage.
                // There is an extra logic in the StickyBucketService to merge new value with the old ones.
                context.userContext.stickyBucketAssignmentDocs = context.userContext.stickyBucketAssignmentDocs ?? [:]
                context.userContext.stickyBucketAssignmentDocs?[key] = doc
                context.options.stickyBucketService?.saveAssignments(doc: doc)
            }
        }
        
        // Fire context.trackingClosure if set and the combination of hashAttribute, hashValue, experiment.key, and variationId has not been tracked before
        if !ExperimentHelper.shared.isTracked(experiment, result) {
            context.options.trackingClosure(experiment, result)
        }

        // Return (in experiment, assigned variation)
        return result
    }

    /// This is a helper method to create an ExperimentResult object.
    private func getExperimentResult(gbContext: EvalContext, experiment: Experiment, variationIndex: Int = 0, hashUsed: Bool, featureId: String? = nil, bucket: Float? = nil, stickyBucketUsed: Bool? = nil) -> ExperimentResult {
        var inExperiment = true
        var variationIndex = variationIndex
        // If assigned variation is not valid, use the baseline and mark the user as not in the experiment
        if (variationIndex < 0 || variationIndex >= experiment.variations.count) {
            variationIndex = 0
            inExperiment = false
        }
        
        var fallback: String? = nil
        if (isStickyBucketetingEnabledForExperimet(context: gbContext, experiment: experiment)) {
            fallback = experiment.fallbackAttribute
        }
        
        let (hastAttribute, hashValue) = Utils.getHashAttribute(attr: experiment.hashAttribute, fallback: fallback, attributes: gbContext.userContext.attributes)
        
        let experimentMeta = experiment.meta ?? []
        let meta = experimentMeta.count > variationIndex ? experimentMeta[variationIndex] : nil
        
        let result = ExperimentResult(inExperiment: inExperiment,
                                      variationId: variationIndex,
                                      value: experiment.variations.count > variationIndex ? experiment.variations[variationIndex] : JSON(),
                                      hashAttribute: hastAttribute,
                                      hashValue: hashValue,
                                      key: meta?.key ?? "\(variationIndex)",
                                      name: meta?.name,
                                      bucket: bucket,
                                      passthrough: meta?.passthrough,
                                      hashUsed: hashUsed,
                                      featureId: featureId,
                                      stickyBucketUsed: stickyBucketUsed ?? false)
        
        return result
    }
    
    private func isStickyBucketetingEnabledForExperimet(context: EvalContext, experiment: Experiment) -> Bool {
        return (context.options.stickyBucketService != nil && !(experiment.disableStickyBucketing ?? true))
    }
}
