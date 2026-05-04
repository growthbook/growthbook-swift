import XCTest
@testable import GrowthBook

class FeatureDecodeTests: XCTestCase {

    // MARK: - Feature

    func testFeatureDecodeDefaultValue() throws {
        let json = """
        {"defaultValue": "blue"}
        """.data(using: .utf8)!

        let feature = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(feature.defaultValue?.stringValue, "blue")
        XCTAssertNil(feature.rules)
    }

    func testFeatureDecodeBoolDefaultValue() throws {
        let json = """
        {"defaultValue": true}
        """.data(using: .utf8)!

        let feature = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(feature.defaultValue?.boolValue, true)
    }

    func testFeatureDecodeNullDefaultValue() throws {
        let json = """
        {"defaultValue": null}
        """.data(using: .utf8)!

        let feature = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertNotNil(feature)
    }

    func testFeatureDecodeWithRules() throws {
        let json = """
        {
            "defaultValue": false,
            "rules": [
                {
                    "id": "rule-1",
                    "condition": {"country": "US"},
                    "force": true,
                    "coverage": 0.5,
                    "hashAttribute": "id",
                    "hashVersion": 2.0,
                    "seed": "test-seed",
                    "name": "US Rule"
                }
            ]
        }
        """.data(using: .utf8)!

        let feature = try JSONDecoder().decode(Feature.self, from: json)
        XCTAssertEqual(feature.defaultValue?.boolValue, false)
        XCTAssertEqual(feature.rules?.count, 1)

        let rule = try XCTUnwrap(feature.rules?.first)
        XCTAssertEqual(rule.id, "rule-1")
        XCTAssertEqual(rule.coverage, 0.5)
        XCTAssertEqual(rule.hashAttribute, "id")
        XCTAssertEqual(rule.hashVersion, 2.0)
        XCTAssertEqual(rule.seed, "test-seed")
        XCTAssertEqual(rule.name, "US Rule")
        XCTAssertEqual(rule.force?.boolValue, true)
    }

    func testFeatureRuleDecodeVariations() throws {
        let json = """
        {
            "id": "exp-rule",
            "variations": ["control", "variant-a", "variant-b"],
            "weights": [0.34, 0.33, 0.33],
            "key": "my-exp-key",
            "hashAttribute": "userId"
        }
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(FeatureRule.self, from: json)
        XCTAssertEqual(rule.variations?.count, 3)
        XCTAssertEqual(rule.variations?[0].stringValue, "control")
        XCTAssertEqual(rule.weights?.count, 3)
        XCTAssertEqual(rule.key, "my-exp-key")
        XCTAssertEqual(rule.hashAttribute, "userId")
    }

    func testFeatureRuleDecodeBucketRanges() throws {
        let json = """
        {
            "id": "range-rule",
            "range": [0.0, 0.5],
            "ranges": [[0.0, 0.25], [0.25, 0.5]]
        }
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(FeatureRule.self, from: json)
        XCTAssertEqual(rule.range?.number1, 0.0)
        XCTAssertEqual(rule.range?.number2, 0.5)
        XCTAssertEqual(rule.ranges?.count, 2)
        XCTAssertEqual(rule.ranges?[0].number1, 0.0)
        XCTAssertEqual(rule.ranges?[0].number2, 0.25)
    }

    func testFeatureRuleDecodeStickyBucketFields() throws {
        let json = """
        {
            "id": "sticky-rule",
            "fallbackAttribute": "deviceId",
            "disableStickyBucketing": true,
            "bucketVersion": 3,
            "minBucketVersion": 1
        }
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(FeatureRule.self, from: json)
        XCTAssertEqual(rule.fallbackAttribute, "deviceId")
        XCTAssertEqual(rule.disableStickyBucketing, true)
        XCTAssertEqual(rule.bucketVersion, 3)
        XCTAssertEqual(rule.minBucketVersion, 1)
    }

    func testFeatureRuleDecodeFilters() throws {
        let json = """
        {
            "id": "filter-rule",
            "filters": [
                {"seed": "filter-seed", "hashVersion": 2, "ranges": [[0.0, 0.5]]}
            ]
        }
        """.data(using: .utf8)!

        let rule = try JSONDecoder().decode(FeatureRule.self, from: json)
        XCTAssertEqual(rule.filters?.count, 1)
        XCTAssertEqual(rule.filters?[0].seed, "filter-seed")
        XCTAssertEqual(rule.filters?[0].ranges.count, 1)
    }

    // MARK: - Experiment

    func testExperimentDecodeBasic() throws {
        // Note: the synthesised Codable uses "isActive" as the JSON key (not "active").
        // "active" is only consumed by the manual init(json:) path used in the evaluator.
        let json = """
        {
            "key": "my-experiment",
            "variations": ["control", "variant"],
            "weights": [0.5, 0.5],
            "isActive": true,
            "coverage": 1.0,
            "hashAttribute": "id",
            "seed": "exp-seed",
            "name": "My Experiment",
            "phase": "2"
        }
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.key, "my-experiment")
        XCTAssertEqual(experiment.variations.count, 2)
        XCTAssertEqual(experiment.weights?.count, 2)
        XCTAssertEqual(experiment.isActive, true)
        XCTAssertEqual(experiment.coverage, 1.0)
        XCTAssertEqual(experiment.hashAttribute, "id")
        XCTAssertEqual(experiment.seed, "exp-seed")
        XCTAssertEqual(experiment.name, "My Experiment")
        XCTAssertEqual(experiment.phase, "2")
    }

    func testExperimentDecodeRanges() throws {
        let json = """
        {
            "key": "range-exp",
            "variations": [0, 1],
            "ranges": [[0.0, 0.5], [0.5, 1.0]]
        }
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.ranges?.count, 2)
        XCTAssertEqual(experiment.ranges?[0].number1, 0.0)
        XCTAssertEqual(experiment.ranges?[0].number2, 0.5)
        XCTAssertEqual(experiment.ranges?[1].number1, 0.5)
        XCTAssertEqual(experiment.ranges?[1].number2, 1.0)
    }

    func testExperimentDecodeStickyBucketFields() throws {
        let json = """
        {
            "key": "sticky-exp",
            "variations": [0, 1],
            "fallbackAttribute": "deviceId",
            "disableStickyBucketing": false,
            "bucketVersion": 2,
            "minBucketVersion": 0,
            "hashVersion": 2.0
        }
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.fallbackAttribute, "deviceId")
        XCTAssertEqual(experiment.disableStickyBucketing, false)
        XCTAssertEqual(experiment.bucketVersion, 2)
        XCTAssertEqual(experiment.minBucketVersion, 0)
        XCTAssertEqual(experiment.hashVersion, 2.0)
    }

    func testExperimentDecodeCondition() throws {
        let json = """
        {
            "key": "cond-exp",
            "variations": [0, 1],
            "condition": {"country": "US", "premium": true}
        }
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.condition?["country"].stringValue, "US")
        XCTAssertEqual(experiment.condition?["premium"].boolValue, true)
    }

    func testExperimentDecodeMeta() throws {
        let json = """
        {
            "key": "meta-exp",
            "variations": [0, 1],
            "meta": [
                {"key": "control", "name": "Control", "passthrough": false},
                {"key": "variant", "name": "Variant A", "passthrough": false}
            ]
        }
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.meta?.count, 2)
        XCTAssertEqual(experiment.meta?[0].key, "control")
        XCTAssertEqual(experiment.meta?[1].name, "Variant A")
    }

    func testExperimentDecodeInactive() throws {
        let json = """
        {"key": "exp", "variations": [0, 1], "isActive": false}
        """.data(using: .utf8)!

        let experiment = try JSONDecoder().decode(Experiment.self, from: json)
        XCTAssertEqual(experiment.isActive, false)
    }

    // MARK: - ExperimentResult

    func testExperimentResultDecode() throws {
        let json = """
        {
            "inExperiment": true,
            "variationId": 1,
            "value": "variant-value",
            "hashAttribute": "id",
            "valueHash": "abc123",
            "key": "my-exp",
            "name": "Variant A",
            "bucket": 0.42,
            "hashUsed": true,
            "featureId": "my-feature",
            "stickyBucketUsed": false
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ExperimentResult.self, from: json)
        XCTAssertEqual(result.inExperiment, true)
        XCTAssertEqual(result.variationId, 1)
        XCTAssertEqual(result.value.stringValue, "variant-value")
        XCTAssertEqual(result.hashAttribute, "id")
        XCTAssertEqual(result.valueHash, "abc123")
        XCTAssertEqual(result.key, "my-exp")
        XCTAssertEqual(result.name, "Variant A")
        XCTAssertEqual(result.bucket, 0.42)
        XCTAssertEqual(result.hashUsed, true)
        XCTAssertEqual(result.featureId, "my-feature")
        XCTAssertEqual(result.stickyBucketUsed, false)
    }

    func testExperimentResultDecodeDefaults() throws {
        let json = """
        {"key": "exp", "value": 0, "variationId": 0, "inExperiment": false}
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(ExperimentResult.self, from: json)
        XCTAssertEqual(result.inExperiment, false)
        XCTAssertNil(result.hashAttribute)
        XCTAssertNil(result.featureId)
        XCTAssertNil(result.stickyBucketUsed)
    }

    // MARK: - FeatureResult

    func testFeatureResultDecodeViaJSON() throws {
        let json = """
        {
            "on": true,
            "off": false,
            "source": "experiment",
            "value": "red",
            "ruleId": "rule-42"
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(FeatureResult.self, from: json)
        XCTAssertEqual(result.isOn, true)
        XCTAssertEqual(result.isOff, false)
        XCTAssertEqual(result.source, "experiment")
        XCTAssertEqual(result.value?.stringValue, "red")
        XCTAssertEqual(result.ruleId, "rule-42")
    }

    func testFeatureResultInit() {
        let result = FeatureResult(value: JSON("green"), isOn: true, source: FeatureSource.force.rawValue, ruleId: "r1")
        XCTAssertEqual(result.isOn, true)
        XCTAssertEqual(result.isOff, false)
        XCTAssertEqual(result.source, "force")
        XCTAssertEqual(result.value?.stringValue, "green")
        XCTAssertEqual(result.ruleId, "r1")
    }

    func testFeatureResultIsOffInvertsIsOn() {
        let onResult  = FeatureResult(value: JSON(true), isOn: true,  source: FeatureSource.defaultValue.rawValue)
        let offResult = FeatureResult(value: JSON(false), isOn: false, source: FeatureSource.defaultValue.rawValue)
        XCTAssertFalse(onResult.isOff)
        XCTAssertTrue(offResult.isOff)
    }

    // MARK: - BucketRange

    func testBucketRangeDecodeFromArray() throws {
        let json = "[0.25, 0.75]".data(using: .utf8)!
        let range = try JSONDecoder().decode(BucketRange.self, from: json)
        XCTAssertEqual(range.number1, 0.25)
        XCTAssertEqual(range.number2, 0.75)
    }

    func testBucketRangeEncodeToArray() throws {
        let range = BucketRange(number1: 0.1, number2: 0.9)
        let encoded = try JSONEncoder().encode(range)
        let decoded = try JSONDecoder().decode([Float].self, from: encoded)
        XCTAssertEqual(decoded[0], 0.1, accuracy: 0.0001)
        XCTAssertEqual(decoded[1], 0.9, accuracy: 0.0001)
    }

    func testBucketRangeRoundtrip() throws {
        let original = BucketRange(number1: 0.3333, number2: 0.6667)
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(BucketRange.self, from: data)
        XCTAssertEqual(decoded.number1, original.number1, accuracy: 0.0001)
        XCTAssertEqual(decoded.number2, original.number2, accuracy: 0.0001)
    }
}
