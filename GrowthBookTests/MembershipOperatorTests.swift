import XCTest
@testable import GrowthBook

/// Covers `$in` / `$ini` / `$nin` / `$nini` across every combination of attribute presence.
///
/// The pair must stay a true logical negation: an attribute the user does not have is genuinely
/// not in the list, so `$in` is false and `$nin` is true. Returning false for both — which is what
/// happens when the operators only return from inside a non-null guard and otherwise drop out of
/// the switch — silently breaks any rule written as an exclusion, such as "serve everyone except
/// these countries".
///
/// The shared spec fixtures (`Source/json.json`, spec 0.7.1) pin `$in` with a missing attribute
/// ("missing attribute - fail") but contain no `$nin` case with a missing or null attribute, so
/// that half is only covered here. Reported in growthbook-swift#185, where the same inputs were
/// measured against growthbook-js 1.7.0 and growthbook-kotlin, which both return true.
class MembershipOperatorTests: XCTestCase {

    private func eval(_ condition: [String: Any], _ attributes: [String: Any]) -> Bool {
        ConditionEvaluator().isEvalCondition(
            attributes: JSON(attributes),
            conditionObj: JSON(condition),
            savedGroups: nil
        )
    }

    private func isIn(_ attributes: [String: Any]) -> Bool {
        eval(["country": ["$in": ["RU", "CN"]]], attributes)
    }

    private func notIn(_ attributes: [String: Any]) -> Bool {
        eval(["country": ["$nin": ["RU", "CN"]]], attributes)
    }

    // MARK: - Attribute present

    func testInMatchesListedValue() {
        XCTAssertTrue(isIn(["country": "RU"]))
    }

    func testInDoesNotMatchUnlistedValue() {
        XCTAssertFalse(isIn(["country": "US"]))
    }

    func testNotInDoesNotMatchListedValue() {
        XCTAssertFalse(notIn(["country": "RU"]))
    }

    func testNotInMatchesUnlistedValue() {
        XCTAssertTrue(notIn(["country": "US"]))
    }

    // MARK: - Attribute absent

    func testInDoesNotMatchWhenAttributeIsAbsent() {
        XCTAssertFalse(isIn(["unrelated": "x"]),
                       "A user without the attribute is not in the list, so $in must not match")
    }

    func testNotInMatchesWhenAttributeIsAbsent() {
        XCTAssertTrue(notIn(["unrelated": "x"]),
                      "A user without the attribute is not in the list, so $nin must match")
    }

    // MARK: - Attribute explicitly null

    func testInDoesNotMatchWhenAttributeIsNull() {
        XCTAssertFalse(eval(["country": ["$in": ["RU", "CN"]]], ["country": NSNull()]))
    }

    func testNotInMatchesWhenAttributeIsNull() {
        XCTAssertTrue(eval(["country": ["$nin": ["RU", "CN"]]], ["country": NSNull()]),
                      "null is not a member of the list, so $nin must match")
    }

    // MARK: - Case-insensitive variants

    func testIniDoesNotMatchWhenAttributeIsAbsent() {
        XCTAssertFalse(eval(["country": ["$ini": ["ru"]]], ["unrelated": "x"]))
    }

    func testNiniMatchesWhenAttributeIsAbsent() {
        XCTAssertTrue(eval(["country": ["$nini": ["ru"]]], ["unrelated": "x"]))
    }

    func testIniStillMatchesRegardlessOfCase() {
        XCTAssertTrue(eval(["country": ["$ini": ["ru"]]], ["country": "RU"]))
    }

    func testNiniStillNegatesACaseInsensitiveMatch() {
        XCTAssertFalse(eval(["country": ["$nini": ["ru"]]], ["country": "RU"]))
    }

    // MARK: - Operators that stay false for an absent attribute

    /// `$all` asks whether every listed value is present in the attribute. An attribute the user
    /// does not have contains nothing, so this stays false — it is not a negation and must not
    /// follow `$nin` out of the gate.
    func testAllDoesNotMatchWhenAttributeIsAbsent() {
        XCTAssertFalse(eval(["tags": ["$all": ["a"]]], ["unrelated": "x"]))
    }

    func testAlliDoesNotMatchWhenAttributeIsAbsent() {
        XCTAssertFalse(eval(["tags": ["$alli": ["a"]]], ["unrelated": "x"]))
    }

    // MARK: - Array attributes keep working

    func testNotInMatchesArrayAttributeWithNoOverlap() {
        XCTAssertTrue(eval(["tags": ["$nin": ["a", "b"]]], ["tags": ["c", "d"]]))
    }

    func testNotInDoesNotMatchArrayAttributeWithOverlap() {
        XCTAssertFalse(eval(["tags": ["$nin": ["a", "b"]]], ["tags": ["c", "a"]]))
    }
}
