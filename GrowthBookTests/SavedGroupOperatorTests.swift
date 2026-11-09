import XCTest
@testable import GrowthBook

/// Covers the `$inGroup` / `$notInGroup` operators across every combination of attribute presence
/// and group resolution.
///
/// The pair must stay a true logical negation: an absent attribute makes the user a non-member, so
/// `$inGroup` is false and `$notInGroup` is true. Returning false for both — which is what happens
/// when the operators only return from inside a non-null guard and otherwise drop out of the
/// switch — silently breaks any rule written as an exclusion.
///
/// The shared spec fixtures (`Source/json.json`, spec 0.7.0) contain no absent-attribute cases for
/// these operators, so this behaviour is only covered here.
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
}
