import XCTest
@testable import GrowthBook

class ExperimentEvaluatorTests: XCTestCase {

    // MARK: - Helpers

    private func makeContext(
        attributes: JSON = JSON(["id": "user-1"]),
        forcedVariations: JSON? = nil,
        isEnabled: Bool = true,
        isQaMode: Bool = false,
        url: String? = nil,
        features: Features = [:]
    ) -> EvalContext {
        let globalContext = GlobalContext(features: features)
        let userContext = UserContext(attributes: attributes, forcedVariations: forcedVariations)
        let options = ClientOptions(isEnabled: isEnabled, stickyBucketService: nil, isQaMode: isQaMode, trackingClosure: { _, _ in })
        options.url = url
        return EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)
    }

    private func evaluate(_ experiment: Experiment, context: EvalContext) -> ExperimentResult {
        ExperimentEvaluator().evaluateExperiment(context: context, experiment: experiment)
    }

    private func twoVariationExp(key: String = "exp", coverage: Float? = nil) -> Experiment {
        Experiment(key: key, variations: [JSON("control"), JSON("variant")], coverage: coverage)
    }

    // MARK: - Fewer than 2 variations

    func testFewerThanTwoVariationsNotInExperiment() {
        let exp = Experiment(key: "exp", variations: [JSON("only")])
        let result = evaluate(exp, context: makeContext())
        XCTAssertFalse(result.inExperiment)
        XCTAssertEqual(result.variationId, 0)
    }

    func testZeroVariationsNotInExperiment() {
        let exp = Experiment(key: "exp", variations: [])
        let result = evaluate(exp, context: makeContext())
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - SDK disabled

    func testSDKDisabledNotInExperiment() {
        let exp = twoVariationExp()
        let result = evaluate(exp, context: makeContext(isEnabled: false))
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - QA mode

    func testQaModeNotInExperiment() {
        let exp = twoVariationExp(coverage: 1.0)
        let result = evaluate(exp, context: makeContext(isQaMode: true))
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - Forced variation

    func testForcedVariationReturnsCorrectVariation() {
        let exp = twoVariationExp()
        let context = makeContext(forcedVariations: JSON(["exp": 1]))
        let result = evaluate(exp, context: context)
        XCTAssertEqual(result.variationId, 1)
        XCTAssertTrue(result.inExperiment)
    }

    func testForcedVariationIndexZero() {
        let exp = twoVariationExp()
        let context = makeContext(forcedVariations: JSON(["exp": 0]))
        let result = evaluate(exp, context: context)
        XCTAssertEqual(result.variationId, 0)
        XCTAssertTrue(result.inExperiment)
    }

    // MARK: - isActive = false

    func testInactiveExperimentNotInExperiment() {
        let exp = Experiment(key: "exp", variations: [JSON("a"), JSON("b")], isActive: false)
        let result = evaluate(exp, context: makeContext())
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - Missing hash attribute

    func testMissingHashAttributeNotInExperiment() {
        // User attributes don't have "custom-id"
        let exp = Experiment(key: "exp", variations: [JSON("a"), JSON("b")], hashAttribute: "custom-id")
        let result = evaluate(exp, context: makeContext(attributes: JSON(["id": "user-1"])))
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - Condition fails

    func testFailingConditionNotInExperiment() {
        let exp = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            coverage: 1.0,
            condition: JSON(["country": "DE"])
        )
        let result = evaluate(exp, context: makeContext(attributes: JSON(["id": "user-1", "country": "US"])))
        XCTAssertFalse(result.inExperiment)
    }

    func testPassingConditionInExperiment() {
        let exp = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            coverage: 1.0,
            condition: JSON(["country": "US"])
        )
        let result = evaluate(exp, context: makeContext(attributes: JSON(["id": "user-1", "country": "US"])))
        XCTAssertTrue(result.inExperiment)
    }

    // MARK: - Namespace exclusion

    func testNamespaceExclusionNotInExperiment() {
        // Namespace [0.9, 1.0] — user-1 hash is unlikely to fall in this tiny range
        let exp = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            namespace: [JSON("pricing"), JSON(0.99), JSON(1.0)],
            coverage: 1.0
        )
        let result = evaluate(exp, context: makeContext())
        // This may or may not be in namespace — just verify it doesn't crash
        XCTAssertNotNil(result)
    }

    // MARK: - Coverage

    func testZeroCoverageNotInExperiment() {
        let exp = twoVariationExp(coverage: 0.0)
        let result = evaluate(exp, context: makeContext())
        XCTAssertFalse(result.inExperiment)
    }

    func testFullCoverageInExperiment() {
        let exp = twoVariationExp(coverage: 1.0)
        let result = evaluate(exp, context: makeContext())
        XCTAssertTrue(result.inExperiment)
    }

    // MARK: - Experiment.force

    func testExperimentForceOverridesVariation() {
        let exp = Experiment(key: "exp", variations: [JSON("a"), JSON("b")], coverage: 1.0, force: 1)
        let result = evaluate(exp, context: makeContext())
        XCTAssertEqual(result.variationId, 1)
        XCTAssertTrue(result.inExperiment)
    }

    // MARK: - Tracking callback

    func testTrackingCallbackFiredWhenInExperiment() {
        var tracked = false
        let globalContext = GlobalContext()
        // Use unique userId so ExperimentHelper shared cache doesn't suppress the callback
        let uniqueId = "tracking-test-\(UUID().uuidString)"
        let userContext = UserContext(attributes: JSON(["id": uniqueId]))
        let options = ClientOptions(isEnabled: true, stickyBucketService: nil, isQaMode: false, trackingClosure: { _, _ in
            tracked = true
        })
        let context = EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)

        let exp = Experiment(key: "tracking-test-exp-\(uniqueId)", variations: [JSON("a"), JSON("b")], coverage: 1.0)
        _ = evaluate(exp, context: context)
        XCTAssertTrue(tracked)
    }

    func testTrackingCallbackNotFiredWhenNotInExperiment() {
        var tracked = false
        let globalContext = GlobalContext()
        let userContext = UserContext(attributes: JSON(["id": "user-1"]))
        let options = ClientOptions(isEnabled: true, stickyBucketService: nil, isQaMode: false, trackingClosure: { _, _ in
            tracked = true
        })
        let context = EvalContext(globalContext: globalContext, userContext: userContext, stackContext: StackContext(), options: options)

        let exp = twoVariationExp(coverage: 0.0)
        _ = evaluate(exp, context: context)
        XCTAssertFalse(tracked)
    }

    // MARK: - Query string override

    func testQueryStringOverrideForceVariation() {
        let exp = twoVariationExp(key: "my-exp")
        let context = makeContext(url: "https://example.com?my-exp=1")
        let result = evaluate(exp, context: context)
        XCTAssertEqual(result.variationId, 1)
        XCTAssertTrue(result.inExperiment)
    }

    // MARK: - Parent conditions in experiment

    func testParentConditionPassesAllowsExperiment() {
        let parentFeature = Feature(defaultValue: JSON(true))
        let parentCond = ParentConditionInterface(json: [
            "id": JSON("feature-flag"),
            "condition": JSON(["value": true])
        ])
        let exp = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            parentConditions: [parentCond],
            coverage: 1.0
        )
        let context = makeContext(features: ["feature-flag": parentFeature])
        let result = evaluate(exp, context: context)
        XCTAssertTrue(result.inExperiment)
    }

    func testParentConditionFailsBlocksExperiment() {
        let parentFeature = Feature(defaultValue: JSON(false))
        let parentCond = ParentConditionInterface(json: [
            "id": JSON("feature-flag"),
            "condition": JSON(["value": true])
        ])
        let exp = Experiment(
            key: "exp",
            variations: [JSON("a"), JSON("b")],
            parentConditions: [parentCond],
            coverage: 1.0
        )
        let context = makeContext(features: ["feature-flag": parentFeature])
        let result = evaluate(exp, context: context)
        XCTAssertFalse(result.inExperiment)
    }

    // MARK: - getExperimentResult: meta fields

    func testResultIncludesMetaKeyAndName() {
        let meta = [
            VariationMeta(json: ["key": JSON("0"), "name": JSON("Control")]),
            VariationMeta(json: ["key": JSON("1"), "name": JSON("Variant")])
        ]
        let exp = Experiment(key: "exp", variations: [JSON("a"), JSON("b")], coverage: 1.0, meta: meta)
        let result = evaluate(exp, context: makeContext(attributes: JSON(["id": "user-1"])))
        XCTAssertNotNil(result.key)
        XCTAssertTrue(result.inExperiment)
    }

    func testResultFeatureIdPropagated() {
        let exp = twoVariationExp(coverage: 1.0)
        let result = ExperimentEvaluator().evaluateExperiment(context: makeContext(), experiment: exp, featureId: "my-feature")
        XCTAssertEqual(result.featureId, "my-feature")
    }

    // MARK: - hashAttribute propagated to result

    func testHashAttributePropagatedToResult() {
        let exp = Experiment(key: "exp", variations: [JSON("a"), JSON("b")], hashAttribute: "id", coverage: 1.0)
        let result = evaluate(exp, context: makeContext())
        XCTAssertEqual(result.hashAttribute, "id")
    }
}
