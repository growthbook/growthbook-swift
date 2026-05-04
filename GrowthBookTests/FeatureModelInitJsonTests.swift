import XCTest
@testable import GrowthBook

/// Tests for the init(json:) initializer paths used by the internal evaluator.
/// These are separate from FeatureModelTests which covers the Codable (JSONDecoder) path.
class FeatureModelInitJsonTests: XCTestCase {

    // MARK: - Feature.init(json:)

    func testFeatureInitJsonDefaultValue() {
        let json: [String: JSON] = ["defaultValue": JSON("blue")]
        let feature = Feature(json: json)
        XCTAssertEqual(feature.defaultValue?.stringValue, "blue")
        XCTAssertNil(feature.rules)
    }

    func testFeatureInitJsonBoolDefaultValue() {
        let json: [String: JSON] = ["defaultValue": JSON(true)]
        let feature = Feature(json: json)
        XCTAssertEqual(feature.defaultValue?.boolValue, true)
    }

    func testFeatureInitJsonWithRules() {
        let ruleJson = JSON(["id": "rule-1", "force": true, "coverage": 0.8])
        let json: [String: JSON] = [
            "defaultValue": JSON(false),
            "rules": JSON([ruleJson])
        ]
        let feature = Feature(json: json)
        XCTAssertEqual(feature.defaultValue?.boolValue, false)
        XCTAssertEqual(feature.rules?.count, 1)
        XCTAssertEqual(feature.rules?.first?.id, "rule-1")
        XCTAssertEqual(feature.rules?.first?.coverage, 0.8)
    }

    func testFeatureInitJsonEmptyRules() {
        let json: [String: JSON] = ["rules": JSON([])]
        let feature = Feature(json: json)
        XCTAssertEqual(feature.rules?.count, 0)
    }

    func testFeatureInitJsonNoKeys() {
        let feature = Feature(json: [:])
        XCTAssertNil(feature.defaultValue)
        XCTAssertNil(feature.rules)
    }

    // MARK: - FeatureRule.init(json:)

    func testFeatureRuleInitJsonBasicFields() {
        let json: [String: JSON] = [
            "id": JSON("rule-abc"),
            "coverage": JSON(0.75),
            "hashAttribute": JSON("userId"),
            "hashVersion": JSON(2.0),
            "seed": JSON("my-seed"),
            "name": JSON("Test Rule"),
            "phase": JSON("1")
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.id, "rule-abc")
        XCTAssertEqual(rule.coverage, 0.75)
        XCTAssertEqual(rule.hashAttribute, "userId")
        XCTAssertEqual(rule.hashVersion, 2.0)
        XCTAssertEqual(rule.seed, "my-seed")
        XCTAssertEqual(rule.name, "Test Rule")
        XCTAssertEqual(rule.phase, "1")
    }

    func testFeatureRuleInitJsonForce() {
        let json: [String: JSON] = ["force": JSON("red")]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.force?.stringValue, "red")
    }

    func testFeatureRuleInitJsonVariations() {
        let json: [String: JSON] = [
            "variations": JSON(["control", "variant-a", "variant-b"])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.variations?.count, 3)
        XCTAssertEqual(rule.variations?[0].stringValue, "control")
    }

    func testFeatureRuleInitJsonWeightsConversion() {
        let json: [String: JSON] = [
            "weights": JSON([0.5, 0.5])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.weights?.count, 2)
        XCTAssertEqual(rule.weights?[0] ?? 0, 0.5, accuracy: 0.001)
        XCTAssertEqual(rule.weights?[1] ?? 0, 0.5, accuracy: 0.001)
    }

    func testFeatureRuleInitJsonRange() {
        let json: [String: JSON] = [
            "range": JSON([0.0, 0.5])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.range?.number1, 0.0)
        XCTAssertEqual(rule.range?.number2, 0.5)
    }

    func testFeatureRuleInitJsonRanges() {
        let json: [String: JSON] = [
            "ranges": JSON([[0.0, 0.25], [0.25, 0.5]])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.ranges?.count, 2)
        XCTAssertEqual(rule.ranges?[0].number1, 0.0)
        XCTAssertEqual(rule.ranges?[0].number2, 0.25)
        XCTAssertEqual(rule.ranges?[1].number1, 0.25)
    }

    func testFeatureRuleInitJsonStickyBucketFields() {
        let json: [String: JSON] = [
            "fallbackAttribute": JSON("deviceId"),
            "disableStickyBucketing": JSON(true),
            "bucketVersion": JSON(3),
            "minBucketVersion": JSON(1)
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.fallbackAttribute, "deviceId")
        XCTAssertEqual(rule.disableStickyBucketing, true)
        XCTAssertEqual(rule.bucketVersion, 3)
        XCTAssertEqual(rule.minBucketVersion, 1)
    }

    func testFeatureRuleInitJsonMeta() {
        let json: [String: JSON] = [
            "meta": JSON([
                ["key": "0", "name": "Control"],
                ["key": "1", "name": "Variant"]
            ])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.meta?.count, 2)
        XCTAssertEqual(rule.meta?[0].key, "0")
        XCTAssertEqual(rule.meta?[1].name, "Variant")
    }

    func testFeatureRuleInitJsonFilters() {
        let json: [String: JSON] = [
            "filters": JSON([
                ["seed": "filter-seed", "hashVersion": 2, "ranges": [[0.0, 0.5]]]
            ])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.filters?.count, 1)
        XCTAssertEqual(rule.filters?[0].seed, "filter-seed")
    }

    func testFeatureRuleInitJsonCondition() {
        let json: [String: JSON] = [
            "condition": JSON(["country": "US", "premium": true])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.condition?["country"].stringValue, "US")
        XCTAssertEqual(rule.condition?["premium"].boolValue, true)
    }

    func testFeatureRuleInitJsonNamespace() {
        let json: [String: JSON] = [
            "namespace": JSON(["pricing", 0.0, 0.5])
        ]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.namespace?.count, 3)
        XCTAssertEqual(rule.namespace?[0].stringValue, "pricing")
    }

    func testFeatureRuleInitJsonKey() {
        let json: [String: JSON] = ["key": JSON("exp-key-123")]
        let rule = FeatureRule(json: json)
        XCTAssertEqual(rule.key, "exp-key-123")
    }

    func testFeatureRuleInitJsonEmptyDict() {
        let rule = FeatureRule(json: [:])
        XCTAssertEqual(rule.id, "")
        XCTAssertNil(rule.coverage)
        XCTAssertNil(rule.force)
        XCTAssertNil(rule.variations)
    }

    // MARK: - Experiment.init(json:)

    func testExperimentInitJsonBasicFields() {
        let json: [String: JSON] = [
            "key": JSON("my-exp"),
            "variations": JSON(["control", "variant"]),
            "hashAttribute": JSON("id"),
            "seed": JSON("exp-seed"),
            "name": JSON("My Experiment"),
            "phase": JSON("2"),
            "coverage": JSON(0.9)
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.key, "my-exp")
        XCTAssertEqual(experiment.variations.count, 2)
        XCTAssertEqual(experiment.hashAttribute, "id")
        XCTAssertEqual(experiment.seed, "exp-seed")
        XCTAssertEqual(experiment.name, "My Experiment")
        XCTAssertEqual(experiment.phase, "2")
        XCTAssertEqual(Double(experiment.coverage ?? 0), 0.9, accuracy: 0.001)
    }

    func testExperimentInitJsonActiveField() {
        // init(json:) reads "active" key, not "isActive" (unlike Codable)
        let activeJson: [String: JSON] = ["key": JSON("exp"), "active": JSON(true)]
        let inactiveJson: [String: JSON] = ["key": JSON("exp"), "active": JSON(false)]

        XCTAssertEqual(Experiment(json: activeJson).isActive, true)
        XCTAssertEqual(Experiment(json: inactiveJson).isActive, false)
    }

    func testExperimentInitJsonDefaultsActiveToTrue() {
        let json: [String: JSON] = ["key": JSON("exp")]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.isActive, true)
    }

    func testExperimentInitJsonWeights() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "weights": JSON([0.34, 0.33, 0.33])
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.weights?.count, 3)
        XCTAssertEqual(experiment.weights?[0] ?? 0, 0.34, accuracy: 0.001)
    }

    func testExperimentInitJsonRanges() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "ranges": JSON([[0.0, 0.5], [0.5, 1.0]])
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.ranges?.count, 2)
        XCTAssertEqual(experiment.ranges?[0].number1, 0.0)
        XCTAssertEqual(experiment.ranges?[0].number2, 0.5)
    }

    func testExperimentInitJsonCondition() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "condition": JSON(["premium": true, "country": "UA"])
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.condition?["premium"].boolValue, true)
        XCTAssertEqual(experiment.condition?["country"].stringValue, "UA")
    }

    func testExperimentInitJsonForce() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "force": JSON(1)
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.force, 1)
    }

    func testExperimentInitJsonStickyBucketFields() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "fallbackAttribute": JSON("deviceId"),
            "disableStickyBucketing": JSON(true),
            "bucketVersion": JSON(2),
            "minBucketVersion": JSON(1),
            "hashVersion": JSON(2.0)
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.fallbackAttribute, "deviceId")
        XCTAssertEqual(experiment.disableStickyBucketing, true)
        XCTAssertEqual(experiment.bucketVersion, 2)
        XCTAssertEqual(experiment.minBucketVersion, 1)
        XCTAssertEqual(experiment.hashVersion, 2.0)
    }

    func testExperimentInitJsonMeta() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "meta": JSON([["key": "0", "name": "Control", "passthrough": false]])
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.meta?.count, 1)
        XCTAssertEqual(experiment.meta?[0].key, "0")
        XCTAssertEqual(experiment.meta?[0].name, "Control")
    }

    func testExperimentInitJsonNamespace() {
        let json: [String: JSON] = [
            "key": JSON("exp"),
            "namespace": JSON(["pricing", 0.0, 0.5])
        ]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.namespace?.count, 3)
        XCTAssertEqual(experiment.namespace?[0].stringValue, "pricing")
    }

    func testExperimentInitJsonEmptyKey() {
        let json: [String: JSON] = [:]
        let experiment = Experiment(json: json)
        XCTAssertEqual(experiment.key, "")
        XCTAssertTrue(experiment.variations.isEmpty)
    }

    // MARK: - ExperimentResult.init(json:)

    func testExperimentResultInitJsonAllFields() {
        let json: [String: JSON] = [
            "inExperiment": JSON(true),
            "variationId": JSON(1),
            "value": JSON("variant"),
            "hashAttribute": JSON("id"),
            "valueHash": JSON("hash-abc"),
            "key": JSON("exp-key"),
            "name": JSON("Variant A"),
            "bucket": JSON(0.42),
            "passthrough": JSON(false),
            "hashUsed": JSON(true),
            "featureId": JSON("my-feature"),
            "stickyBucketUsed": JSON(false)
        ]
        let result = ExperimentResult(json: json)
        XCTAssertEqual(result.inExperiment, true)
        XCTAssertEqual(result.variationId, 1)
        XCTAssertEqual(result.value.stringValue, "variant")
        XCTAssertEqual(result.hashAttribute, "id")
        XCTAssertEqual(result.valueHash, "hash-abc")
        XCTAssertEqual(result.key, "exp-key")
        XCTAssertEqual(result.name, "Variant A")
        XCTAssertEqual(Double(result.bucket ?? 0), 0.42, accuracy: 0.001)
        XCTAssertEqual(result.passthrough, false)
        XCTAssertEqual(result.hashUsed, true)
        XCTAssertEqual(result.featureId, "my-feature")
        XCTAssertEqual(result.stickyBucketUsed, false)
    }

    func testExperimentResultInitJsonDefaults() {
        let result = ExperimentResult(json: [:])
        XCTAssertEqual(result.inExperiment, false)
        XCTAssertEqual(result.variationId, 0)
        XCTAssertEqual(result.key, "")
        XCTAssertNil(result.hashAttribute)
        XCTAssertNil(result.featureId)
    }

    // MARK: - FeatureResult.init(json:)

    func testFeatureResultInitJsonUsesOnOffKeys() {
        // init(json:) reads "on"/"off" keys — different from Codable which reads "isOn"/"isOff"
        let json: [String: JSON] = [
            "on": JSON(true),
            "off": JSON(false),
            "source": JSON("force"),
            "value": JSON(42),
            "ruleId": JSON("rule-99")
        ]
        let result = FeatureResult(json: json)
        XCTAssertEqual(result.isOn, true)
        XCTAssertEqual(result.isOff, false)
        XCTAssertEqual(result.source, "force")
        XCTAssertEqual(result.value?.intValue, 42)
        XCTAssertEqual(result.ruleId, "rule-99")
    }

    func testFeatureResultInitJsonDefaultsOnToTrue() {
        // When "on" key is missing, isOn defaults to true
        let result = FeatureResult(json: [:])
        XCTAssertEqual(result.isOn, true)
        XCTAssertEqual(result.isOff, false)
        XCTAssertEqual(result.source, "")
        XCTAssertEqual(result.ruleId, "")
    }

    func testFeatureResultInitJsonWithNestedExperiment() {
        let json: [String: JSON] = [
            "on": JSON(true),
            "off": JSON(false),
            "source": JSON("experiment"),
            "value": JSON("red"),
            "experiment": JSON(["key": "color-exp", "variations": ["red", "blue"]]),
            "experimentResult": JSON([
                "inExperiment": true,
                "variationId": 0,
                "value": "red",
                "key": "0"
            ])
        ]
        let result = FeatureResult(json: json)
        XCTAssertEqual(result.source, "experiment")
        XCTAssertEqual(result.experiment?.key, "color-exp")
        XCTAssertEqual(result.experimentResult?.variationId, 0)
    }

    func testFeatureResultInitJsonValueFallsBackToEmptyJson() {
        // When "value" key is missing, value defaults to JSON() (empty)
        let result = FeatureResult(json: ["source": JSON("defaultValue")])
        XCTAssertNotNil(result.value)
    }
}
