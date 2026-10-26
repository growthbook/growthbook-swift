import XCTest
@testable import GrowthBook

class ConditionEvaluatorTests: XCTestCase {

    private let eval = ConditionEvaluator()

    // MARK: - getAttributeType

    func testGetAttributeTypeCoversAllIndices() {
        XCTAssertEqual(getAttributeType(index: 0), "number")
        XCTAssertEqual(getAttributeType(index: 1), "string")
        XCTAssertEqual(getAttributeType(index: 2), "boolean")
        XCTAssertEqual(getAttributeType(index: 3), "array")
        XCTAssertEqual(getAttributeType(index: 4), "object")
        XCTAssertEqual(getAttributeType(index: 5), "null")
        XCTAssertEqual(getAttributeType(index: 6), "unknown")
        XCTAssertEqual(getAttributeType(index: 99), "unknown")
    }

    // MARK: - isEvalCondition: $nor / $not

    func testEvalConditionNorFalseWhenAllMatch() {
        let attrs = JSON(["x": 1])
        let cond = JSON(["$nor": [["x": 1]]])
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    func testEvalConditionNorTrueWhenNoneMatch() {
        let attrs = JSON(["x": 2])
        let cond = JSON(["$nor": [["x": 1]]])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    func testEvalConditionNotTrueWhenInnerFails() {
        let attrs = JSON(["x": 2])
        let cond = JSON(["$not": ["x": 1]])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    func testEvalConditionNotFalseWhenInnerMatches() {
        let attrs = JSON(["x": 1])
        let cond = JSON(["$not": ["x": 1]])
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    // MARK: - isEvalOr: empty array

    func testEvalOrEmptyArrayReturnsTrue() {
        XCTAssertTrue(eval.isEvalOr(attributes: JSON([:]), conditionObjs: [], savedGroups: nil))
    }

    // MARK: - getPath

    func testGetPathDotNotation() {
        let attrs = JSON(["user": ["id": "abc"]])
        let result = eval.getPath(obj: attrs, key: "user.id")
        XCTAssertEqual(result?.stringValue, "abc")
    }

    func testGetPathDotNotationMissing() {
        let attrs = JSON(["user": ["id": "abc"]])
        XCTAssertNil(eval.getPath(obj: attrs, key: "user.name"))
    }

    func testGetPathWhenIntermediateIsArray() {
        let attrs = JSON(["items": [1, 2, 3]])
        XCTAssertNil(eval.getPath(obj: attrs, key: "items.0"))
    }

    func testGetPathSimpleKey() {
        let attrs = JSON(["country": "UA"])
        XCTAssertEqual(eval.getPath(obj: attrs, key: "country")?.stringValue, "UA")
    }

    // MARK: - isEvalConditionValue: primitives and null

    func testEvalConditionValueNullCondWithNilAttr() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON.null, attributeValue: nil))
    }

    func testEvalConditionValueNullCondWithNullAttr() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON.null, attributeValue: JSON.null))
    }

    func testEvalConditionValueNullCondWithNonNullAttr() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON.null, attributeValue: JSON("value")))
    }

    func testEvalConditionValueStringMatch() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON("en"), attributeValue: JSON("en")))
    }

    func testEvalConditionValueStringMismatch() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON("en"), attributeValue: JSON("de")))
    }

    func testEvalConditionValueNumberMatch() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON(42), attributeValue: JSON(42)))
    }

    func testEvalConditionValueNumberMismatch() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON(42), attributeValue: JSON(43)))
    }

    func testEvalConditionValueBoolMatch() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON(true), attributeValue: JSON(true)))
    }

    func testEvalConditionValueBoolMismatch() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON(true), attributeValue: JSON(false)))
    }

    func testEvalConditionValueInsensitiveMatch() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON("Hello"), attributeValue: JSON("hello"), insensitive: true))
    }

    func testEvalConditionValueInsensitiveMismatch() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON("Hello"), attributeValue: JSON("world"), insensitive: true))
    }

    // MARK: - isEvalConditionValue: array deep equality

    func testEvalConditionValueArrayEqual() {
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: JSON([1, 2]), attributeValue: JSON([1, 2])))
    }

    func testEvalConditionValueArrayCountMismatch() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON([1, 2, 3]), attributeValue: JSON([1, 2])))
    }

    func testEvalConditionValueArrayNotArray() {
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: JSON([1, 2]), attributeValue: JSON("not-array")))
    }

    // MARK: - isEvalConditionValue: object comparison

    func testEvalConditionValueNonOperatorObjectDeepEqual() {
        let cond = JSON(["a": 1, "b": 2])
        let attr = JSON(["a": 1, "b": 2])
        XCTAssertTrue(eval.isEvalConditionValue(conditionValue: cond, attributeValue: attr))
    }

    func testEvalConditionValueNonOperatorObjectVsNonObject() {
        let cond = JSON(["a": 1])
        XCTAssertFalse(eval.isEvalConditionValue(conditionValue: cond, attributeValue: JSON("string")))
    }

    // MARK: - isElemMatch

    func testElemMatchWithOperatorCondition() {
        let items: [JSON] = [JSON(1), JSON(2), JSON(3)]
        let condition = JSON(["$gt": 2])
        XCTAssertTrue(eval.isElemMatch(attributeValue: items, condition: condition, savedGroups: nil))
    }

    func testElemMatchWithObjectCondition() {
        let items: [JSON] = [JSON(["x": 1]), JSON(["x": 2])]
        let condition = JSON(["x": 2])
        XCTAssertTrue(eval.isElemMatch(attributeValue: items, condition: condition, savedGroups: nil))
    }

    func testElemMatchNoMatch() {
        let items: [JSON] = [JSON(1), JSON(2)]
        let condition = JSON(["$gt": 10])
        XCTAssertFalse(eval.isElemMatch(attributeValue: items, condition: condition, savedGroups: nil))
    }

    func testElemMatchEmptyArray() {
        XCTAssertFalse(eval.isElemMatch(attributeValue: [], condition: JSON(["$gt": 0]), savedGroups: nil))
    }

    // MARK: - $type operator

    func testTypeOperatorString() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$type", attributeValue: JSON("hello"), conditionValue: JSON("string")))
    }

    func testTypeOperatorNumber() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$type", attributeValue: JSON(42), conditionValue: JSON("number")))
    }

    func testTypeOperatorMismatch() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$type", attributeValue: JSON(42), conditionValue: JSON("string")))
    }

    // MARK: - $not operator

    func testNotOperatorTrue() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$not", attributeValue: JSON(5), conditionValue: JSON(["$gt": 10])))
    }

    func testNotOperatorFalse() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$not", attributeValue: JSON(15), conditionValue: JSON(["$gt": 10])))
    }

    // MARK: - $eq / $ne

    func testEqOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON(5), conditionValue: JSON(5)))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON(5), conditionValue: JSON(6)))
    }

    func testNeOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON(5), conditionValue: JSON(6)))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON(5), conditionValue: JSON(5)))
    }

    // MARK: - $lt / $lte / $gt / $gte with null attribute (a null attribute is not ordered, so all fail)

    func testLtWithNullAttrPositiveCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON.null, conditionValue: JSON(1)))
    }

    func testLtWithNullAttrNegativeCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON.null, conditionValue: JSON(-1)))
    }

    func testLteWithNullAttrZeroCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lte", attributeValue: JSON.null, conditionValue: JSON(0)))
    }

    func testGtWithNullAttrNegativeCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON.null, conditionValue: JSON(-1)))
    }

    func testGtWithNullAttrPositiveCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON.null, conditionValue: JSON(1)))
    }

    func testGteWithNullAttrZeroCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON.null, conditionValue: JSON(0)))
    }

    // MARK: - $lt / $gt with string attributes

    func testLtWithStrings() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("apple"), conditionValue: JSON("banana")))
    }

    func testGtWithStrings() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON("banana"), conditionValue: JSON("apple")))
    }

    /// Two strings compare as text, even when they look like numbers
    func testLtWithStringNumbers() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("3"), conditionValue: JSON("10")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("10"), conditionValue: JSON("9")))
    }

    // MARK: - $ini / $nini (case-insensitive in/nin)

    func testIniOperatorCaseInsensitive() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ini", attributeValue: JSON("Hello"), conditionValue: JSON(["hello", "world"])))
    }

    func testNiniOperatorCaseInsensitive() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$nini", attributeValue: JSON("HELLO"), conditionValue: JSON(["hello"])))
    }

    // MARK: - $all / $alli

    func testAllOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$all", attributeValue: JSON(["a", "b", "c"]), conditionValue: JSON(["a", "b"])))
    }

    func testAllOperatorMissing() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$all", attributeValue: JSON(["a"]), conditionValue: JSON(["a", "b"])))
    }

    func testAlliOperatorCaseInsensitive() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$alli", attributeValue: JSON(["A", "B"]), conditionValue: JSON(["a", "b"])))
    }

    // MARK: - $elemMatch / $size

    func testElemMatchOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: JSON([1, 5, 10]), conditionValue: JSON(["$gt": 4])))
    }

    func testSizeOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$size", attributeValue: JSON(["a", "b", "c"]), conditionValue: JSON(3)))
    }

    func testSizeOperatorMismatch() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$size", attributeValue: JSON(["a"]), conditionValue: JSON(3)))
    }

    // MARK: - $regex / $regexi / $notRegex / $notRegexi

    func testRegexOperatorMatch() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$regex", attributeValue: JSON("hello world"), conditionValue: JSON("hel+")))
    }

    func testRegexOperatorNoMatch() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$regex", attributeValue: JSON("hello"), conditionValue: JSON("^world")))
    }

    func testRegexiCaseInsensitive() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$regexi", attributeValue: JSON("Hello"), conditionValue: JSON("hello")))
    }

    func testNotRegex() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$notRegex", attributeValue: JSON("hello"), conditionValue: JSON("^world")))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$notRegex", attributeValue: JSON("hello"), conditionValue: JSON("hello")))
    }

    func testNotRegexi() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$notRegexi", attributeValue: JSON("Hello"), conditionValue: JSON("^world")))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$notRegexi", attributeValue: JSON("Hello"), conditionValue: JSON("hello")))
    }

    /// A non-string pattern is malformed, so it must not turn into an empty pattern that matches
    /// every string. Like a pattern that doesn't compile, neither the operator nor its negation matches.
    func testNonStringRegexPatternMatchesNothing() {
        for pattern in [JSON(["^US$"]), JSON(1), JSON(true), JSON(["a": "b"]), JSON(NSNull())] {
            for op in ["$regex", "$regexi", "$notRegex", "$notRegexi"] {
                XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: op, attributeValue: JSON("CA"), conditionValue: pattern),
                               "\(op) with pattern \(pattern.rawString() ?? "?")")
            }
        }
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["country": "CA"]), conditionObj: JSON(["country": ["$regex": ["^US$"]]])))
    }

    // MARK: - Version operators

    func testVeqOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$veq", attributeValue: JSON("1.0.0"), conditionValue: JSON("1.0.0")))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$veq", attributeValue: JSON("1.0.0"), conditionValue: JSON("2.0.0")))
    }

    func testVneOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$vne", attributeValue: JSON("1.0.0"), conditionValue: JSON("2.0.0")))
    }

    func testVgtOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$vgt", attributeValue: JSON("2.0.0"), conditionValue: JSON("1.0.0")))
    }

    func testVgteOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$vgte", attributeValue: JSON("1.0.0"), conditionValue: JSON("1.0.0")))
    }

    func testVlteOperator() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$vlte", attributeValue: JSON("1.0.0"), conditionValue: JSON("1.0.0")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$vlte", attributeValue: JSON("0.9.0"), conditionValue: JSON("1.0.0")))
    }

    // MARK: - $inGroup / $notInGroup

    func testInGroupOperator() {
        let savedGroups = JSON(["beta-users": ["user-1", "user-2"]])
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$inGroup", attributeValue: JSON("user-1"), conditionValue: JSON("beta-users"), savedGroups: savedGroups))
    }

    func testInGroupOperatorNotMember() {
        let savedGroups = JSON(["beta-users": ["user-1"]])
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$inGroup", attributeValue: JSON("user-99"), conditionValue: JSON("beta-users"), savedGroups: savedGroups))
    }

    func testNotInGroupOperator() {
        let savedGroups = JSON(["beta-users": ["user-1"]])
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$notInGroup", attributeValue: JSON("user-99"), conditionValue: JSON("beta-users"), savedGroups: savedGroups))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$notInGroup", attributeValue: JSON("user-1"), conditionValue: JSON("beta-users"), savedGroups: savedGroups))
    }

    // MARK: - Unknown operator

    func testUnknownOperatorReturnsFalse() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$unknown", attributeValue: JSON("x"), conditionValue: JSON("x")))
    }

    // MARK: - Full condition via isEvalCondition

    func testFullConditionWithSavedGroup() {
        let attrs = JSON(["userId": "user-1"])
        let savedGroups = JSON(["testers": ["user-1", "user-2"]])
        let cond = JSON(["userId": ["$inGroup": "testers"]])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: cond, savedGroups: savedGroups))
    }

    func testFullConditionAndOperator() {
        let attrs = JSON(["age": 25, "country": "US"])
        let cond = JSON(["$and": [["age": ["$gte": 18]], ["country": "US"]]])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    func testFullConditionDotPath() {
        let attrs = JSON(["user": ["role": "admin"]])
        let cond = JSON(["user.role": "admin"])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: cond))
    }

    // MARK: - Version operators

    func testVersionOperatorWithLongNumericSegment() {
        let attrs = JSON(["version": "20260910.1.1"])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vgt": "20260909.9.9"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vlt": "20260911.0.0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["version": "1.0.0"]), conditionObj: JSON(["version": ["$vlt": "123456789"]])))
    }

    func testVersionOperatorKeepsInnerLetterV() {
        let attrs = JSON(["version": "1.2.3-dev"])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$veq": "1.2.3-dev"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vne": "1.2.3-de"]])))
    }

    /// A number is only compared as a version against another number
    func testVersionOperatorNumericAttribute() {
        let attrs = JSON(["version": 2])
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vgt": "1.0.0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vne": "1.0.0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$veq": 2]])))
    }

    /// An absent, boolean or collection attribute is not a version: every operator fails except $vne
    func testVersionOperatorWithNonVersionAttribute() {
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON([:]), conditionObj: JSON(["version": ["$vlt": "0.0.1"]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["version": true]), conditionObj: JSON(["version": ["$veq": "0"]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["version": ["1.0.0"]]), conditionObj: JSON(["version": ["$veq": "0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON([:]), conditionObj: JSON(["version": ["$vne": "0"]])))
    }

    /// An operator this SDK can't evaluate leaves `$all`/`$alli` undecided, so `$not` can't flip it to a pass (as in JS)
    func testAllWithUnknownOperatorUnderNotFails() {
        let attrs = JSON(["tags": ["a"]])
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$not": ["$all": [["$future": "x"]]]]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$not": ["$alli": [["$future": "x"]]]]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$all": [["$future": "x"]]]])))
        // A decided miss still decides it
        XCTAssertFalse(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$all": ["b", ["$future": "x"]]]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$not": ["$all": ["b", ["$future": "x"]]]]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["tags": ["$all": ["a"]]])))
    }

    /// Strings compare by UTF-16 code units, as in JS: "\u{E9}" and "e\u{301}" render the same but differ
    func testCanonicallyEquivalentStringsAreNotEqual() {
        let precomposed = "\u{E9}"
        let decomposed = "e\u{301}"
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["name": decomposed]), conditionObj: JSON(["name": precomposed])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["profile": ["name": decomposed]]), conditionObj: JSON(["profile": ["name": precomposed]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["names": [decomposed]]), conditionObj: JSON(["names": [precomposed]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["name": decomposed]), conditionObj: JSON(["name": ["$in": [precomposed]]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["name": decomposed]), conditionObj: JSON(["name": ["$nin": [precomposed]]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["name": decomposed]), conditionObj: JSON(["name": ["$eq": precomposed]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["profile": ["name": precomposed]]), conditionObj: JSON(["profile": ["name": precomposed]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["name": precomposed]), conditionObj: JSON(["name": ["$in": [precomposed]]])))
    }

    /// NaN is unordered, so every ordering operator fails with NaN on either side (as in JS)
    func testOrderingOperatorsFailWithNaN() {
        for op in ["$lt", "$lte", "$gt", "$gte"] {
            XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["x": Double.nan]), conditionObj: JSON(["x": [op: 1]])), op)
            XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: op, attributeValue: JSON(1), conditionValue: JSON(Double.nan)), op)
            XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: op, attributeValue: JSON(Double.nan), conditionValue: JSON(Double.nan)), op)
        }
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["x": 2]), conditionObj: JSON(["x": ["$gt": 1]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["x": 1]), conditionObj: JSON(["x": ["$gte": 1]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["x": -0.0]), conditionObj: JSON(["x": ["$gte": 0]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["x": -0.0]), conditionObj: JSON(["x": ["$gt": 0]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["x": "b"]), conditionObj: JSON(["x": ["$gt": "a"]])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["x": "a"]), conditionObj: JSON(["x": ["$gt": "a"]])))
    }
}
