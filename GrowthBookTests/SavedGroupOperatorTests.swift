import XCTest
@testable import GrowthBook

/// Covers the `$inGroup` / `$notInGroup` operators across every combination of attribute presence
/// and group resolution.
///
/// The pair must stay a true logical negation wherever the group resolves at all: an absent
/// attribute makes the user a non-member, so `$inGroup` is false and `$notInGroup` is true.
/// Returning false for both — which is what happens when the operators only return from inside a
/// non-null guard and otherwise drop out of the switch — silently breaks any rule written as an
/// exclusion. The one deliberate exception is an entry the operators cannot read, covered at the
/// end of this file.
///
/// The shared spec fixtures (`Source/json.json`, spec 0.9.0) carry no absent-attribute cases for
/// these operators, and its `savedGroupReferencesV2` section exercises typed entries only against a
/// scalar attribute that is present, so those combinations are covered here instead.
class SavedGroupOperatorTests: XCTestCase {

    private let savedGroups = JSON(["vips": ["u1", "u2"], "empty": [] as [String]])

    private func eval(_ condition: [String: Any], _ attributes: [String: Any]) -> Bool {
        ConditionEvaluator().isEvalCondition(
            attributes: JSON(attributes),
            conditionObj: JSON(condition),
            savedGroups: savedGroups
        )
    }

    private func inGroup(_ group: String, _ attributes: [String: Any]) -> Bool {
        eval(["id": ["$inGroup": group]], attributes)
    }

    private func notInGroup(_ group: String, _ attributes: [String: Any]) -> Bool {
        eval(["id": ["$notInGroup": group]], attributes)
    }

    // MARK: - Attribute present

    func testInGroupMatchesMember() {
        XCTAssertTrue(inGroup("vips", ["id": "u1"]))
    }

    func testInGroupDoesNotMatchNonMember() {
        XCTAssertFalse(inGroup("vips", ["id": "other"]))
    }

    func testNotInGroupDoesNotMatchMember() {
        XCTAssertFalse(notInGroup("vips", ["id": "u1"]))
    }

    func testNotInGroupMatchesNonMember() {
        XCTAssertTrue(notInGroup("vips", ["id": "other"]))
    }

    // MARK: - Attribute absent

    func testInGroupDoesNotMatchWhenAttributeIsAbsent() {
        XCTAssertFalse(inGroup("vips", ["unrelated": "x"]))
    }

    func testNotInGroupMatchesWhenAttributeIsAbsent() {
        XCTAssertTrue(notInGroup("vips", ["unrelated": "x"]),
                      "An absent attribute makes the user a non-member, so $notInGroup must match")
    }

    func testGroupOperatorsStayNegationsOfEachOtherForAbsentAttribute() {
        let attributes = ["unrelated": "x"]
        XCTAssertNotEqual(inGroup("vips", attributes), notInGroup("vips", attributes))
    }

    // MARK: - Unknown or empty group

    func testInGroupDoesNotMatchUnknownGroup() {
        XCTAssertFalse(inGroup("no-such-group", ["id": "u1"]))
    }

    func testNotInGroupMatchesUnknownGroup() {
        XCTAssertTrue(notInGroup("no-such-group", ["id": "u1"]))
    }

    func testInGroupDoesNotMatchEmptyGroup() {
        XCTAssertFalse(inGroup("empty", ["id": "u1"]))
    }

    func testNotInGroupMatchesEmptyGroup() {
        XCTAssertTrue(notInGroup("empty", ["id": "u1"]))
    }

    // MARK: - No savedGroups supplied at all

    func testGroupOperatorsWithoutSavedGroups() {
        let evaluator = ConditionEvaluator()
        let attributes = JSON(["id": "u1"])

        XCTAssertFalse(evaluator.isEvalCondition(
            attributes: attributes,
            conditionObj: JSON(["id": ["$inGroup": "vips"]]),
            savedGroups: nil
        ))
        XCTAssertTrue(evaluator.isEvalCondition(
            attributes: attributes,
            conditionObj: JSON(["id": ["$notInGroup": "vips"]]),
            savedGroups: nil
        ))
    }

    // MARK: - Malformed group id

    func testNonStringGroupIdResolvesToEmptyGroup() {
        XCTAssertFalse(eval(["id": ["$inGroup": 42]], ["id": "u1"]))
        XCTAssertTrue(eval(["id": ["$notInGroup": 42]], ["id": "u1"]))
    }

    // MARK: - Array attributes

    func testInGroupMatchesWhenAnyArrayElementIsAMember() {
        XCTAssertTrue(inGroup("vips", ["id": ["other", "u2"]]))
        XCTAssertFalse(notInGroup("vips", ["id": ["other", "u2"]]))
    }

    func testInGroupDoesNotMatchWhenNoArrayElementIsAMember() {
        XCTAssertFalse(inGroup("vips", ["id": ["a", "b"]]))
        XCTAssertTrue(notInGroup("vips", ["id": ["a", "b"]]))
    }

    // MARK: - Typed `savedGroupReferencesV2` entries

    /// A payload carrying typed entries beside the v1 bare arrays above. `$inGroup` / `$notInGroup`
    /// predate this format and can only read the list flavour; everything else must fail closed.
    ///
    /// The spec's `savedGroupReferencesV2` section asserts these outcomes for a scalar attribute
    /// that is present. The cases below are the combinations it does not carry — an absent
    /// attribute, an array attribute, and a list entry whose `values` are missing or empty — which
    /// matter here precisely because the operators are dispatched above the attribute-shape branch.
    private let typedGroups = JSON([
        "list": ["type": "list", "attributeKey": "id", "values": ["u1", "u2"]],
        "condition": ["type": "condition", "condition": ["plan": "pro"]],
        "future": ["type": "somethingNew", "values": ["u1"]],
        "noValues": ["type": "list", "attributeKey": "id"],
        "emptyValues": ["type": "list", "attributeKey": "id", "values": [] as [String]],
    ])

    private func evalTyped(_ condition: [String: Any], _ attributes: [String: Any]) -> Bool {
        ConditionEvaluator().isEvalCondition(
            attributes: JSON(attributes),
            conditionObj: JSON(condition),
            savedGroups: typedGroups
        )
    }

    private func inTypedGroup(_ group: String, _ attributes: [String: Any]) -> Bool {
        evalTyped(["id": ["$inGroup": group]], attributes)
    }

    private func notInTypedGroup(_ group: String, _ attributes: [String: Any]) -> Bool {
        evalTyped(["id": ["$notInGroup": group]], attributes)
    }

    func testTypedListEntryBehavesLikeABareArray() {
        XCTAssertTrue(inTypedGroup("list", ["id": "u1"]))
        XCTAssertFalse(notInTypedGroup("list", ["id": "u1"]))

        XCTAssertFalse(inTypedGroup("list", ["id": "other"]))
        XCTAssertTrue(notInTypedGroup("list", ["id": "other"]))
    }

    func testTypedListEntryWithAbsentAttribute() {
        XCTAssertFalse(inTypedGroup("list", ["unrelated": "x"]))
        XCTAssertTrue(notInTypedGroup("list", ["unrelated": "x"]),
                      "An absent attribute makes the user a non-member, so $notInGroup must match")
    }

    func testTypedListEntryWithArrayAttribute() {
        XCTAssertTrue(inTypedGroup("list", ["id": ["other", "u2"]]))
        XCTAssertFalse(notInTypedGroup("list", ["id": ["other", "u2"]]))
    }

    func testEmptyTypedListLeavesTheNegationIntact() {
        XCTAssertFalse(inTypedGroup("emptyValues", ["id": "u1"]))
        XCTAssertTrue(notInTypedGroup("emptyValues", ["id": "u1"]),
                      "An entry that declares no members is readable, so the pair stays a negation")
    }

    // MARK: - Entries these operators cannot read

    /// An entry `$inGroup` / `$notInGroup` cannot read fails **both** of them, so here the pair is
    /// deliberately not a negation. Resolving such an entry to an empty list instead would be the
    /// loud failure: `$notInGroup` would pass everyone through a rule meant to exclude them.
    ///
    /// This is the one place the operators' documented symmetry is broken on purpose, so each
    /// unreadable shape is asserted for both polarities rather than just the interesting one.
    func testUnreadableEntriesFailClosedForBothPolarities() {
        for group in ["condition", "future", "noValues"] {
            XCTAssertFalse(inTypedGroup(group, ["id": "u1"]), "$inGroup should fail closed for \(group)")
            XCTAssertFalse(notInTypedGroup(group, ["id": "u1"]), "$notInGroup should fail closed for \(group)")
        }
    }

    func testUnreadableEntriesFailClosedForAnArrayAttribute() {
        XCTAssertFalse(inTypedGroup("condition", ["id": ["u1", "u2"]]))
        XCTAssertFalse(notInTypedGroup("condition", ["id": ["u1", "u2"]]))
    }

    func testUnreadableEntriesFailClosedForAnAbsentAttribute() {
        XCTAssertFalse(inTypedGroup("condition", ["unrelated": "x"]))
        XCTAssertFalse(notInTypedGroup("condition", ["unrelated": "x"]),
                       "Fail-closed outranks the absent-attribute rule: the entry is unusable either way")
    }

    /// An id simply missing from the payload keeps the older, documented behaviour — an empty group
    /// rather than a failure — so an exclusion rule still passes. This is the line that separates
    /// "absent" from "present but unreadable", and every SDK implements it.
    func testAbsentIdStillResolvesToAnEmptyGroup() {
        XCTAssertFalse(inTypedGroup("no-such-group", ["id": "u1"]))
        XCTAssertTrue(notInTypedGroup("no-such-group", ["id": "u1"]))
    }
}
