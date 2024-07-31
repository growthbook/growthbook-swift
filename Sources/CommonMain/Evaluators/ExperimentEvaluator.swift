import Foundation

/// Experiment Evaluator Class
/// 
/// Takes Context & Experiment & returns Experiment Result
class ExperimentEvaluator {
    var attributeOverrides: JSON = JSON()
    
    init(attributeOverrides: JSON) {
        self.attributeOverrides = attributeOverrides
    }
    
    /// Takes Context & Experiment & returns Experiment Result
    func evaluateExperiment(context: Context, experiment: Experiment) -> ExperimentResult {
        // If experiment.variations has fewer than 2 variations, return immediately (not in experiment, variationId 0)
        //
        // If context.enabled is false, return immediately (not in experiment, variationId 0)
        if experiment.variations.count < 2 || !context.isEnabled {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }
        
        // If context.forcedVariations[experiment.trackingKey] is defined, return immediately (not in experiment, forced variation)
        if let forcedVariation = context.forcedVariations?.dictionaryValue[experiment.key] {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forcedVariation.intValue, hashUsed: false)
        }
        
        // If experiment.action is set to false, return immediately (not in experiment, variationId 0)
        if !experiment.isActive {
            // TODO: check status == draft scenario
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }
        
        let (hashAttribute, hashValue) = Utils.getHashAttribute(context: context, attr: experiment.hashAttribute, fallback: (context.stickyBucketService != nil && !(experiment.disableStickyBucketing ?? true)) ? experiment.fallbackAttribute : nil, attributeOverrides: attributeOverrides)

        if hashValue.isEmpty {
            print("Skip because missing hashAttribute")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }
        var assigned = -1
        var foundStickyBucket = false
        var stickyBucketVersionIsBlocked = false
        
        if context.stickyBucketService != nil, !(experiment.disableStickyBucketing ?? true) {
            let (variation, versionIsBlocked) = Utils.getStickyBucketVariation(context: context,
                                                                               experimentKey: experiment.key,
                                                                               experimentBucketVersion: experiment.bucketVersion ?? 0,
                                                                               minExperimentBucketVersion: experiment.minBucketVersion ?? 0,
                                                                               meta: experiment.meta ?? [],
                                                                               expFallBackAttribute: experiment.fallbackAttribute,
                                                                               expHashAttribute: experiment.hashAttribute,
                                                                               attributeOverrides: attributeOverrides)
            
            foundStickyBucket = variation >= 0;
            assigned = variation
            stickyBucketVersionIsBlocked = versionIsBlocked ?? false
        }
        
        // Some checks are not needed if we already have a sticky bucket
        if !foundStickyBucket {
            if let filters = experiment.filters {
                if Utils.isFilteredOut(filters: filters, context: context, attributeOverrides: attributeOverrides) {
                    print("Skip because of filters")
                    return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
                }
            } else if let namespaceExperiment = experiment.namespace,
                      let namespace = Utils.getGBNameSpace(namespace: namespaceExperiment),
                      !Utils.inNamespace(userId: hashValue, namespace: namespace) {
                print("Skip because of namespace")
                return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
            }
            //TODO: check what is include
            
            // If experiment.condition is set and the condition evaluates to false, return immediately (not in experiment, variationId 0)
            if let condition = experiment.condition {
                if !ConditionEvaluator().isEvalCondition(attributes: context.attributes, conditionObj: condition, savedGroups: context.savedGroups) {
                    return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
                }
            }
            
            if let parentConditions = experiment.parentConditions {
                for parentCondition in parentConditions {
                    
                    // TODO: option is to not pass attributeOverrides
                    let parentResult = FeatureEvaluator(context: context, featureKey: parentCondition.id, attributeOverrides: JSON(parentCondition.condition)).evaluateFeature()
                    
                    if parentResult.source == FeatureSource.cyclicPrerequisite.rawValue {
                        return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
                    }
                    
                    let evalObj = ["value": parentResult.value]
                    let evalCondition = ConditionEvaluator().isEvalCondition(
                        attributes: JSON(evalObj),
                        conditionObj: parentCondition.condition, 
                        savedGroups: context.savedGroups
                    )
                    
                    // blocking prerequisite eval failed: feature evaluation fails
                    if !evalCondition {
                        return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
                    }
                }
            }
        }
        
        let hash = Utils.hash(seed: experiment.seed ?? experiment.key, value: hashValue, version: experiment.hashVersion ?? 1)
        
        guard let hash = hash else {
            print("Skip because of invalid hash version")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }
        
        if !foundStickyBucket {
            let ranges = experiment.ranges ?? Utils.getBucketRanges(numVariations: experiment.variations.count, coverage: experiment.coverage ?? 1, weights: experiment.weights)
            assigned = Utils.chooseVariation(n: hash, ranges: ranges)
        }
        
        if stickyBucketVersionIsBlocked {
            print("Skip because sticky bucket version is blocked")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false, bucket: nil, stickyBucketUsed: true)
        }
        
        // If not assigned a variation (assigned === -1), return immediately (not in experiment, variationId 0)
        if assigned < 0 {
            print("Skip because of coverage")
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }

        // If experiment.force is set, return immediately (not in experiment, variationId experiment.force)
        if let forceExp = experiment.force {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: forceExp, hashUsed: false)
        }

        // If context.qaMode is true, return immediately (not in experiment, variationId 0)
        if context.isQaMode {
            return getExperimentResult(gbContext: context, experiment: experiment, variationIndex: -1, hashUsed: false)
        }
        
        let result = getExperimentResult(gbContext: context, experiment: experiment, variationIndex: assigned, hashUsed: true, bucket: hash, stickyBucketUsed: foundStickyBucket)
        print("ExperimentResult: \(result)")
        if context.stickyBucketService != nil && !(experiment.disableStickyBucketing ?? true) {
            let (key, doc, changed) = Utils.generateStickyBucketAssignmentDoc(context: context,
                                                                        attributeName: hashAttribute,
                                                                        attributeValue: hashValue,
                                                                        assignments: [Utils.getStickyBucketExperimentKey(experiment.key,
                                                                                                                   experiment.bucketVersion ?? 0): result.key])
            if changed {
                context.stickyBucketAssignmentDocs = context.stickyBucketAssignmentDocs ?? [:]
                context.stickyBucketAssignmentDocs?[key] = doc
                context.stickyBucketService?.saveAssignments(doc: doc)
            }
        }
        
        // Fire context.trackingClosure if set and the combination of hashAttribute, hashValue, experiment.key, and variationId has not been tracked before
        if !ExperimentHelper.shared.isTracked(experiment, result) {
            context.trackingClosure(experiment, result)
        }

        // Return (in experiment, assigned variation)
        return result
    }

    /// This is a helper method to create an ExperimentResult object.
    private func getExperimentResult(gbContext: Context, experiment: Experiment, variationIndex: Int = 0, hashUsed: Bool, featureId: String? = nil, bucket: Float? = nil, stickyBucketUsed: Bool? = nil) -> ExperimentResult {
        var inExperiment = true
        var variationIndex = variationIndex
        // If assigned variation is not valid, use the baseline and mark the user as not in the experiment
        if (variationIndex < 0 || variationIndex >= experiment.variations.count) {
            variationIndex = 0
            inExperiment = false
        }
        
        let (hastAttribute, hashValue) = Utils.getHashAttribute(context: gbContext, attr: experiment.hashAttribute, fallback: (gbContext.stickyBucketService != nil && !(experiment.disableStickyBucketing ?? true)) ? experiment.fallbackAttribute : nil, attributeOverrides: attributeOverrides)
        
        let experimentMeta = experiment.meta ?? []
        let meta = experimentMeta.count > variationIndex ? experimentMeta[variationIndex] : nil
        
        let result = ExperimentResult(inExperiment: inExperiment,
                                      variationId: variationIndex,
                                      value: experiment.variations.count > variationIndex ? experiment.variations[variationIndex] : JSON(),
                                      hashAttribute: hastAttribute,
                                      hashValue: hashValue,
                                      key: meta?.key ?? "\(variationIndex)",
                                      hashUsed: hashUsed,
                                      featureId: featureId,
                                      stickyBucketUsed: stickyBucketUsed ?? false)
        
        if let name = meta?.name {
            result.name = name
        }
        
        if let bucket = bucket {
            result.bucket = bucket
        }
        
        if let passthrough = meta?.passthrough {
            result.passthrough = passthrough
        }
        
        return result
    }
}
