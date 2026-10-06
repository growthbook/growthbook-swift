import XCTest
@testable import GrowthBook

/// Runs the `savedGroupReferencesV2` section of the vendored conformance suite: resolving a saved
/// group of any type by reference, through the `$savedGroup` operator.
///
/// These cases live under their own key rather than in `evalCondition` / `feature` / `run`, so an
/// SDK without the capability skips them wholesale — the same arrangement as `stickyBucket` and
/// `contextualBandit`. They are kept in one class here for the same reason: the section is a unit,
/// and splitting it across the three existing runners would hide which spec version each tracks.
///
/// The `feature` and `run` sections are not redundant with `evalCondition`. Both carry a case whose
/// reference sits inside a prerequisite gate, and a gate that forgets to pass `savedGroups` down
/// resolves every reference to "matches nobody" while every condition-level case still passes.
///
/// A missing or empty section fails loudly rather than returning early: the whole point of these
/// tests is the case set, so a corpus that no longer carries it must not read as success.
class SavedGroupReferencesV2SpecTests: XCTestCase {

    // MARK: - evalCondition

    func testEvalConditionSpec() {
        let cases = section(TestHelper().getSavedGroupReferencesV2ConditionData(), "evalCondition")
        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let condition = testCase[1]
            let attributes = testCase[2]
            let expected = testCase[3].boolValue
            // The fifth element is optional in the spec's tuple, and absent means "no saved groups".
            let savedGroups: JSON? = testCase.arrayValue.count > 4 ? testCase[4] : nil

            let actual = ConditionEvaluator().isEvalCondition(
                attributes: attributes,
                conditionObj: condition,
                savedGroups: savedGroups
            )

            if actual != expected {
                failures.append("• \(name)\n    expected \(expected), got \(actual)")
            }
        }

        report(failures, of: cases.count, section: "evalCondition")
    }

    // MARK: - feature

    func testFeatureSpec() {
        let cases = section(TestHelper().getSavedGroupReferencesV2FeatureData(), "feature")
        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let testData = FeaturesTest(json: testCase[1].dictionaryValue)
            let expected = FeatureResultTest(json: testCase[3].dictionaryValue)

            let context = Context(apiHost: nil,
                                  streamingHost: nil,
                                  clientKey: nil,
                                  encryptionKey: nil,
                                  isEnabled: true,
                                  attributes: testData.attributes,
                                  forcedVariations: testData.forcedVariations,
                                  isQaMode: false,
                                  trackingClosure: { _, _ in },
                                  backgroundSync: false,
                                  savedGroups: testData.savedGroups)
            if let features = testData.features {
                context.features = features
            }

            let result = FeatureEvaluator(
                context: Utils.initializeEvalContext(context: context),
                featureKey: testCase[2].stringValue
            ).evaluateFeature()

            var mismatches: [String] = []
            check("value", result.value, expected.value, into: &mismatches)
            check("on", result.isOn, expected.isOn, into: &mismatches)
            check("off", result.isOff, expected.isOff, into: &mismatches)
            check("source", result.source, expected.source, into: &mismatches)
            check("ruleId", result.ruleId, expected.ruleId, into: &mismatches)

            if !mismatches.isEmpty {
                failures.append("• \(name)\n    " + mismatches.joined(separator: "\n    "))
            }
        }

        report(failures, of: cases.count, section: "feature")
    }

    // MARK: - run

    func testRunSpec() {
        let cases = section(TestHelper().getSavedGroupReferencesV2RunData(), "run")
        var failures: [String] = []

        for testCase in cases {
            let name = testCase[0].stringValue
            let testContext = ContextTest(json: testCase[1].dictionaryValue)
            let experiment = Experiment(json: testCase[2].dictionaryValue)

            let context = Context(apiHost: nil,
                                  streamingHost: nil,
                                  clientKey: nil,
                                  encryptionKey: nil,
                                  isEnabled: testContext.isEnabled,
                                  attributes: testContext.attributes,
                                  forcedVariations: testContext.forcedVariations,
                                  isQaMode: testContext.isQaMode,
                                  trackingClosure: { _, _ in },
                                  features: testContext.features,
                                  backgroundSync: false,
                                  savedGroups: testContext.savedGroups,
                                  url: testContext.url)

            let result = ExperimentEvaluator().evaluateExperiment(
                context: Utils.initializeEvalContext(context: context),
                experiment: experiment
            )

            var mismatches: [String] = []
            check("value", result.value, testCase[3], into: &mismatches)
            check("inExperiment", result.inExperiment, testCase[4].boolValue, into: &mismatches)
            // `hashUsed` separates a genuine assignment from a prerequisite-blocked one, so it is
            // asserted here even though the existing `run` runner does not.
            check("hashUsed", result.hashUsed ?? false, testCase[5].boolValue, into: &mismatches)

            if !mismatches.isEmpty {
                failures.append("• \(name)\n    " + mismatches.joined(separator: "\n    "))
            }
        }

        report(failures, of: cases.count, section: "run")
    }

    // MARK: - Helpers

    /// Returns the section's cases, or an empty array after recording a failure.
    ///
    /// Deliberately not `throw XCTSkip`: XCTest reports a thrown skip as a skip outcome, and a CI
    /// configuration that counts skips apart from failures would then read a vanished section as
    /// "not run" rather than "broken" — the exact reading this suite exists to prevent. Returning
    /// empty leaves the recorded failure as the only outcome, and the caller's loop over zero cases
    /// adds nothing to it.
    private func section(_ cases: [JSON]?, _ name: String) -> [JSON] {
        guard let cases, !cases.isEmpty else {
            XCTFail("savedGroupReferencesV2.\(name) is missing from the conformance fixtures")
            return []
        }
        return cases
    }

    private func check<T: Equatable>(_ field: String, _ actual: T?, _ expected: T?, into mismatches: inout [String]) {
        if actual != expected {
            mismatches.append("\(field): expected \(describe(expected)), got \(describe(actual))")
        }
    }

    private func describe<T>(_ value: T?) -> String {
        guard let value else { return "nil" }
        return "\(value)"
    }

    private func report(_ failures: [String], of total: Int, section: String) {
        if !failures.isEmpty {
            XCTFail("\(failures.count) of \(total) savedGroupReferencesV2.\(section) cases failed:\n"
                    + failures.joined(separator: "\n"))
        }
    }
}
