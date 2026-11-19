import XCTest

@testable import GrowthBook

/// Makes sure every section of the vendored spec (`Source/json.json`) is either run by a test here
/// or excluded on purpose, so a corpus update can't add cases that nothing reads.
class SpecCoverageTests: XCTestCase {

    /// Sections a spec-driven test reads, with the test that runs it. Nested sections use a dotted path.
    static let runSections: [String: String] = [
        "evalCondition": "ConditionTests.testConditions",
        "hash": "UtilsTests (getFNVHashData)",
        "getBucketRange": "UtilsTests (getBucketRangeData)",
        "feature": "FeatureValueTests (getFeatureData)",
        "run": "ExperimentRunTests (getRunExperimentData)",
        "chooseVariation": "UtilsTests (getChooseVariationData)",
        "getQueryStringOverride": "UtilsTests.testQueryStringOverride",
        "inNamespace": "UtilsTests (getInNameSpaceData)",
        "getEqualWeights": "UtilsTests (getEqualWeightsData)",
        "decrypt": "UtilsTests.testDecrypt",
        "stickyBucket": "StickyBucketingTests (getStickyBucketingData)",
        "contextualBandit": "ContextualBanditSpecTests (getContextualBanditData)",
        "savedGroupReferencesV2.evalCondition": "SavedGroupReferencesV2SpecTests",
        "savedGroupReferencesV2.feature": "SavedGroupReferencesV2SpecTests",
        "savedGroupReferencesV2.run": "SavedGroupReferencesV2SpecTests",
        "savedGroupReferencesRemote.evalCondition": "SavedGroupReferencesRemoteSpecTests",
        "savedGroupReferencesRemote.feature": "SavedGroupReferencesRemoteSpecTests",
    ]

    /// Sections deliberately not run, with the reason. Remove an entry once the SDK supports it.
    static let excludedSections: [String: String] = [
        "urlRedirect": "URL redirects are a browser feature; this SDK doesn't implement them.",
        "pruneCondition": "Payload reduction methods are not implemented for client SDKs to start with.",
        "reducePayload": "Payload reduction methods are not implemented for client SDKs to start with.",
    ]

    /// Every case section in the corpus. A top-level object holds nested sections, listed as `parent.child`.
    private func specSections() -> Set<String> {
        guard let spec = TestHelper().getSpecData()?.dictionaryValue else { return [] }
        var sections = Set<String>()
        for (key, value) in spec {
            if value.array != nil {
                sections.insert(key)
            } else if let nested = value.dictionary {
                for (child, childValue) in nested where childValue.array != nil {
                    sections.insert("\(key).\(child)")
                }
            }
        }
        return sections
    }

    func testEverySpecSectionIsRunOrExcluded() {
        let sections = specSections()
        XCTAssertFalse(sections.isEmpty, "Could not read any sections from the spec corpus")

        for section in sections.sorted() {
            let run = Self.runSections[section] != nil
            let excluded = Self.excludedSections[section] != nil
            XCTAssertTrue(run || excluded,
                          "Spec section \(section) is neither run by a test nor listed in excludedSections")
            XCTAssertFalse(run && excluded, "Spec section \(section) is both run and excluded")
        }
    }

    func testListedSectionsExistInSpec() {
        let sections = specSections()
        for section in Set(Self.runSections.keys).union(Self.excludedSections.keys).sorted() {
            XCTAssertTrue(sections.contains(section),
                          "\(section) is listed in SpecCoverageTests but isn't in the spec corpus")
        }
    }
}
