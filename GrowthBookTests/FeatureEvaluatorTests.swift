import XCTest
@testable import GrowthBook

class FeatureEvaluatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext(
        features: Features = [:],
        attributes: JSON = JSON(["id": "user-1"]),
        forcedFeatureValues: JSON? = nil,
        savedGroups: JSON? = nil
    ) -> EvalContext {
        let globalContext = GlobalContext(features: features, savedGroups: savedGroups)
        let userContext = UserContext(attributes: attributes, forcedFeatureValues: forcedFeatureValues)
        let options = ClientOptions(isEnabled: true, stickyBucketService: nil, isQaMode: false, trackingClosure: { _, _ in })
        return EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)
    }

    private func evaluate(_ featureKey: String, in context: EvalContext) -> FeatureResult {
        FeatureEvaluator(context: context, featureKey: featureKey).evaluateFeature()
    }

    // MARK: - Unknown feature

    func testUnknownFeatureReturnsUnknownSource() {
        let result = evaluate("nonexistent", in: makeContext())
        XCTAssertEqual(result.source, FeatureSource.unknownFeature.rawValue)
        XCTAssertEqual(result.value, JSON.null)
        XCTAssertFalse(result.isOn)
    }

    // MARK: - Default value

    func testDefaultValueReturnedWhenNoRulesMatch() {
        let feature = Feature(defaultValue: JSON("blue"))
        let result = evaluate("color", in: makeContext(features: ["color": feature]))
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
        XCTAssertEqual(result.value?.stringValue, "blue")
    }

    func testNullDefaultValue() {
        let feature = Feature(defaultValue: nil)
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
        XCTAssertEqual(result.value, JSON.null)
    }

    // MARK: - Forced feature value (override)

    func testForcedFeatureValueOverridesEvaluation() {
        let feature = Feature(defaultValue: JSON("original"))
        let context = makeContext(
            features: ["color": feature],
            forcedFeatureValues: JSON(["color": "forced"])
        )
        let result = evaluate("color", in: context)
        XCTAssertEqual(result.source, FeatureSource.override.rawValue)
        XCTAssertEqual(result.value?.stringValue, "forced")
    }

    func testForcedFeatureValueBool() {
        let feature = Feature(defaultValue: JSON(false))
        let context = makeContext(
            features: ["flag": feature],
            forcedFeatureValues: JSON(["flag": true])
        )
        let result = evaluate("flag", in: context)
        XCTAssertEqual(result.source, FeatureSource.override.rawValue)
        XCTAssertTrue(result.isOn)
    }

    // MARK: - Circular dependency

    func testCircularDependencyReturnsCorrectSource() {
        let feature = Feature(defaultValue: JSON("x"))
        let context = makeContext(features: ["my-feature": feature])
        context.stackContext.evaluatedFeatures.insert("my-feature")
        let result = evaluate("my-feature", in: context)
        XCTAssertEqual(result.source, FeatureSource.cyclicPrerequisite.rawValue)
        XCTAssertEqual(result.value, JSON.null)
    }

    // MARK: - Force rule

    func testForceRuleNoConditionReturnsForce() {
        let rule = FeatureRule(force: JSON("red"))
        let feature = Feature(defaultValue: JSON("blue"), rules: [rule])
        let result = evaluate("color", in: makeContext(features: ["color": feature]))
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "red")
    }

    func testForceRuleWithPassingCondition() {
        let rule = FeatureRule(condition: JSON(["country": "US"]), force: JSON("red"))
        let feature = Feature(defaultValue: JSON("blue"), rules: [rule])
        let context = makeContext(
            features: ["color": feature],
            attributes: JSON(["id": "user-1", "country": "US"])
        )
        let result = evaluate("color", in: context)
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "red")
    }

    func testForceRuleWithFailingConditionFallsToDefault() {
        let rule = FeatureRule(condition: JSON(["country": "DE"]), force: JSON("red"))
        let feature = Feature(defaultValue: JSON("blue"), rules: [rule])
        let context = makeContext(
            features: ["color": feature],
            attributes: JSON(["id": "user-1", "country": "US"])
        )
        let result = evaluate("color", in: context)
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
        XCTAssertEqual(result.value?.stringValue, "blue")
    }

    func testForceRuleUserExcludedFromRollout() {
        // coverage=0 means no one is in the rollout
        let rule = FeatureRule(coverage: 0.0, force: JSON("forced"))
        let feature = Feature(defaultValue: JSON("default"), rules: [rule])
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
    }

    func testForceRuleWithRangeSkipsCoverageCheck() {
        // When range is set, the separate coverage check block is skipped
        let range = BucketRange(json: JSON([0.0, 1.0]))
        let rule = FeatureRule(coverage: 1.0, force: JSON("forced"), range: range)
        let feature = Feature(defaultValue: JSON("default"), rules: [rule])
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "forced")
    }

    func testForceRuleNoVariationsRuleContinues() {
        // Rule without force AND without variations → skipped
        let skipRule = FeatureRule(condition: JSON(["x": 1]))
        let forceRule = FeatureRule(force: JSON("result"))
        let feature = Feature(defaultValue: JSON("default"), rules: [skipRule, forceRule])
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "result")
    }

    // MARK: - Prerequisite conditions

    func testPrerequisiteGateBlocksFeatureWhenConditionFails() {
        // "premium" feature returns false by default
        let premiumFeature = Feature(defaultValue: JSON(false))

        // "color" requires premium == true (gate=true blocks the whole feature)
        let parentCond = ParentConditionInterface(json: [
            "id": JSON("premium"),
            "condition": JSON(["value": true]),
            "gate": JSON(true)
        ])
        let rule = FeatureRule(parentConditions: [parentCond], force: JSON("red"))
        let colorFeature = Feature(defaultValue: JSON("blue"), rules: [rule])

        let context = makeContext(features: ["premium": premiumFeature, "color": colorFeature])
        let result = evaluate("color", in: context)
        XCTAssertEqual(result.source, FeatureSource.prerequisite.rawValue)
        XCTAssertEqual(result.value, JSON.null)
    }

    func testPrerequisiteGateAllowsFeatureWhenConditionPasses() {
        // "premium" returns true
        let premiumFeature = Feature(defaultValue: JSON(true))

        let parentCond = ParentConditionInterface(json: [
            "id": JSON("premium"),
            "condition": JSON(["value": true]),
            "gate": JSON(true)
        ])
        let rule = FeatureRule(parentConditions: [parentCond], force: JSON("red"))
        let colorFeature = Feature(defaultValue: JSON("blue"), rules: [rule])

        let context = makeContext(features: ["premium": premiumFeature, "color": colorFeature])
        let result = evaluate("color", in: context)
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "red")
    }

    func testNonBlockingPrerequisiteSkipsRuleWhenFails() {
        // gate is nil → non-blocking: just skip this rule
        let premiumFeature = Feature(defaultValue: JSON(false))

        let parentCond = ParentConditionInterface(json: [
            "id": JSON("premium"),
            "condition": JSON(["value": true])
            // no "gate" key → gate = nil
        ])
        let prereqRule = FeatureRule(parentConditions: [parentCond], force: JSON("red"))
        let fallbackRule = FeatureRule(force: JSON("fallback"))
        let colorFeature = Feature(defaultValue: JSON("blue"), rules: [prereqRule, fallbackRule])

        let context = makeContext(features: ["premium": premiumFeature, "color": colorFeature])
        let result = evaluate("color", in: context)
        // prereqRule is skipped → fallbackRule applies
        XCTAssertEqual(result.source, FeatureSource.force.rawValue)
        XCTAssertEqual(result.value?.stringValue, "fallback")
    }

    func testCyclicPrerequisiteDetected() {
        // A depends on B, B depends on A → cycle
        let parentCondA = ParentConditionInterface(json: [
            "id": JSON("feature-b"),
            "condition": JSON(["value": true]),
            "gate": JSON(true)
        ])
        let parentCondB = ParentConditionInterface(json: [
            "id": JSON("feature-a"),
            "condition": JSON(["value": true]),
            "gate": JSON(true)
        ])

        let ruleA = FeatureRule(parentConditions: [parentCondA], force: JSON("a"))
        let ruleB = FeatureRule(parentConditions: [parentCondB], force: JSON("b"))

        let featureA = Feature(defaultValue: JSON("default-a"), rules: [ruleA])
        let featureB = Feature(defaultValue: JSON("default-b"), rules: [ruleB])

        let context = makeContext(features: ["feature-a": featureA, "feature-b": featureB])
        let result = evaluate("feature-a", in: context)
        XCTAssertEqual(result.source, FeatureSource.cyclicPrerequisite.rawValue)
    }

    // MARK: - Experiment rule

    func testExperimentRuleNotInExperimentFallsToDefault() {
        // coverage=0 → no one in experiment → falls through to default
        let rule = FeatureRule(
            coverage: 0.0,
            variations: [JSON("control"), JSON("variant")]
        )
        let feature = Feature(defaultValue: JSON("default"), rules: [rule])
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.defaultValue.rawValue)
    }

    func testExperimentRuleInExperimentReturnsExperimentSource() {
        // coverage=1 → user is in experiment
        let rule = FeatureRule(
            coverage: 1.0,
            variations: [JSON("control"), JSON("variant")],
            weights: [0.5, 0.5]
        )
        let feature = Feature(defaultValue: JSON("default"), rules: [rule])
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertEqual(result.source, FeatureSource.experiment.rawValue)
    }

    // MARK: - prepareResult: isOn/isOff logic

    func testIsOffForFalseStringValue() {
        let feature = Feature(defaultValue: JSON("false"))
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertFalse(result.isOn)
        XCTAssertTrue(result.isOff)
    }

    func testIsOffForZeroStringValue() {
        let feature = Feature(defaultValue: JSON("0"))
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertFalse(result.isOn)
    }

    func testIsOnForNonEmptyStringValue() {
        let feature = Feature(defaultValue: JSON("enabled"))
        let result = evaluate("flag", in: makeContext(features: ["flag": feature]))
        XCTAssertTrue(result.isOn)
        XCTAssertFalse(result.isOff)
    }
}
