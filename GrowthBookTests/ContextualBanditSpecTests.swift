import XCTest
@testable import GrowthBook

/// Runs the `contextualBandit` section of the vendored conformance suite.
///
/// The existing `feature` runner cannot be reused: these cases assert the bandit fields the SDK adds
/// to the result (`leafId`, `variationWeights`, `banditVersion`) and the selection recorded on the
/// experiment, none of which `FeatureResultTest` models. They also carry `contextualBandits`,
/// `qaMode`, `enabled` and `url` in the case context.
///
/// A field is only compared when the case declares it, so cases that deliberately omit
/// `banditVersion` assert its absence rather than accidentally passing.
class ContextualBanditSpecTests: XCTestCase {

    func testContextualBanditSpec() throws {
        guard let cases = TestHelper().getContextualBanditData(), !cases.isEmpty else {
            XCTFail("contextualBandit section is missing from the conformance fixtures")
            return
        }

        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let input = testCase[1].dictionaryValue
            let featureKey = testCase[2].stringValue
            let expected = testCase[3].dictionaryValue

            let result = evaluate(input: input, featureKey: featureKey)
            let mismatches = compare(result: result, expected: expected)

            if !mismatches.isEmpty {
                failures.append("• \(name)\n    " + mismatches.joined(separator: "\n    "))
            }
        }

        if !failures.isEmpty {
            XCTFail("\(failures.count) of \(cases.count) contextual bandit cases failed:\n"
                    + failures.joined(separator: "\n"))
        }
    }

    // MARK: - Evaluation

    private func evaluate(input: [String: JSON], featureKey: String) -> FeatureResult {
        let testData = FeaturesTest(json: input)

        let context = Context(
            apiHost: nil,
            streamingHost: nil,
            clientKey: nil,
            encryptionKey: nil,
            isEnabled: input["enabled"]?.bool ?? true,
            attributes: testData.attributes,
            forcedVariations: testData.forcedVariations,
            isQaMode: input["qaMode"]?.bool ?? false,
            trackingClosure: { _, _ in },
            backgroundSync: false,
            savedGroups: testData.savedGroups,
            contextualBandits: input["contextualBandits"],
            url: input["url"]?.string
        )
        if let features = testData.features {
            context.features = features
        }

        let evalContext = Utils.initializeEvalContext(context: context)
        return FeatureEvaluator(context: evalContext, featureKey: featureKey).evaluateFeature()
    }

    // MARK: - Comparison

    private func compare(result: FeatureResult, expected: [String: JSON]) -> [String] {
        var mismatches: [String] = []

        func check<T: Equatable>(_ field: String, _ actual: T?, _ expectedValue: T?) {
            if actual != expectedValue {
                mismatches.append("\(field): expected \(describe(expectedValue)), got \(describe(actual))")
            }
        }

        if let value = expected["value"] { check("value", result.value, value) }
        if let on = expected["on"] { check("on", result.isOn, on.boolValue) }
        if let off = expected["off"] { check("off", result.isOff, off.boolValue) }
        if let source = expected["source"] { check("source", result.source, source.stringValue) }
        if let ruleId = expected["ruleId"] { check("ruleId", result.ruleId ?? "", ruleId.stringValue) }

        // The experiment is only asserted for its key and the bandit selection attached to it; the
        // rest of its fields are echoes of the rule and are already covered by the feature section.
        if let experiment = expected["experiment"]?.dictionary {
            check("experiment.key", result.experiment?.key, experiment["key"]?.stringValue)
            check("experiment.weights", result.experiment?.weights,
                  experiment["weights"].map { JSON.convertToArrayFloat(jsonArray: $0.arrayValue) })

            if let bandit = experiment["contextualBandit"]?.dictionary {
                let actual = result.experiment?.contextualBandit
                check("experiment.contextualBandit.leafId", actual?.leafId, bandit["leafId"]?.int)
                check("experiment.contextualBandit.variationWeights", actual?.variationWeights,
                      bandit["variationWeights"].map { JSON.convertToArrayFloat(jsonArray: $0.arrayValue) })
                check("experiment.contextualBandit.banditVersion", actual?.banditVersion, bandit["banditVersion"]?.int)
            } else if result.experiment?.contextualBandit != nil {
                mismatches.append("experiment.contextualBandit: expected none, got a selection")
            }
        }

        if let expectedResult = expected["experimentResult"]?.dictionary {
            let actual = result.experimentResult
            check("experimentResult.variationId", actual?.variationId, expectedResult["variationId"]?.int)
            check("experimentResult.key", actual?.key, expectedResult["key"]?.stringValue)
            check("experimentResult.value", actual?.value, expectedResult["value"])
            check("experimentResult.inExperiment", actual?.inExperiment, expectedResult["inExperiment"]?.bool)
            check("experimentResult.hashUsed", actual?.hashUsed, expectedResult["hashUsed"]?.bool)
            check("experimentResult.hashAttribute", actual?.hashAttribute, expectedResult["hashAttribute"]?.string)
            check("experimentResult.hashValue", actual?.valueHash, expectedResult["hashValue"]?.string)
            check("experimentResult.featureId", actual?.featureId, expectedResult["featureId"]?.string)
            check("experimentResult.stickyBucketUsed", actual?.stickyBucketUsed, expectedResult["stickyBucketUsed"]?.bool)
            if let bucket = expectedResult["bucket"]?.float {
                check("experimentResult.bucket", actual?.bucket, bucket)
            }
            // Declared explicitly so an omitted field asserts absence.
            check("experimentResult.leafId", actual?.leafId, expectedResult["leafId"]?.int)
            check("experimentResult.variationWeights", actual?.variationWeights,
                  expectedResult["variationWeights"].map { JSON.convertToArrayFloat(jsonArray: $0.arrayValue) })
            check("experimentResult.banditVersion", actual?.banditVersion, expectedResult["banditVersion"]?.int)
        } else if result.experimentResult != nil, expected["experiment"] == nil {
            mismatches.append("experimentResult: expected none, got one")
        }

        return mismatches
    }

    private func describe<T>(_ value: T?) -> String {
        guard let value else { return "nil" }
        return "\(value)"
    }
}
