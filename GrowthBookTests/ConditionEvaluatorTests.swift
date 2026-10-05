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

    // MARK: - $lt / $lte / $gt / $gte with null attribute

    func testLtWithNullAttrPositiveCond() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON.null, conditionValue: JSON(1)))
    }

    func testLtWithNullAttrNegativeCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON.null, conditionValue: JSON(-1)))
    }

    func testLteWithNullAttrZeroCond() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lte", attributeValue: JSON.null, conditionValue: JSON(0)))
    }

    func testGtWithNullAttrNegativeCond() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON.null, conditionValue: JSON(-1)))
    }

    func testGtWithNullAttrPositiveCond() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON.null, conditionValue: JSON(1)))
    }

    func testGteWithNullAttrZeroCond() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON.null, conditionValue: JSON(0)))
    }

    /// A numeric condition sent as a string is inclusive, like the numeric one: `age >= "18"` passes
    /// for 18. The string branch used to compare with `>`, so the boundary value was excluded.
    func testGteWithNumericAttrAndStringCondIsInclusive() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON(18), conditionValue: JSON("18")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON(19), conditionValue: JSON("18")))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$gte", attributeValue: JSON(17), conditionValue: JSON("18")))
    }

    // MARK: - Range operators follow JavaScript's relational comparison

    private func range(_ op: String, _ attribute: JSON, _ condition: JSON) -> Bool {
        eval.isEvalOperatorCondition(operatorKey: op, attributeValue: attribute, conditionValue: condition)
    }

    /// Every range operator reads a numeric-string attribute against a number; `$gte` alone used not to.
    func testRangeOperatorsAllReadANumericStringAgainstANumber() {
        XCTAssertTrue(range("$gt", JSON("10"), JSON(9)))
        XCTAssertTrue(range("$gte", JSON("10"), JSON(10)))
        XCTAssertTrue(range("$lt", JSON("10"), JSON(11)))
        XCTAssertTrue(range("$lte", JSON("10"), JSON(10)))
    }

    /// A value with no numeric reading is `NaN`, so no direction holds. `$gt` used to fall back to a
    /// text comparison against the number's text, so `"abc" > 1`.
    func testRangeOperatorsMatchNoDirectionForANonNumericString() {
        for op in ["$lt", "$lte", "$gt", "$gte"] {
            XCTAssertFalse(range(op, JSON("abc"), JSON(1)), "\(op) \"abc\" vs 1")
            XCTAssertFalse(range(op, JSON(1), JSON("abc")), "\(op) 1 vs \"abc\"")
        }
    }

    /// `Number()` trims whitespace and reads `""` as 0; `Double(String)` did neither.
    func testRangeOperatorsConvertStringsAsJavaScriptNumberDoes() {
        XCTAssertTrue(range("$lt", JSON(" 5 "), JSON(10)))
        XCTAssertTrue(range("$lt", JSON(""), JSON(1)))
        XCTAssertTrue(range("$lt", JSON("0x10"), JSON(20)))
        XCTAssertTrue(range("$gt", JSON("0x10"), JSON(15)))
        XCTAssertFalse(range("$lt", JSON("1f"), JSON(2)))
        // Swift reads these, JavaScript does not
        XCTAssertFalse(range("$lt", JSON("nan"), JSON(2)))
        XCTAssertFalse(range("$lt", JSON("0x1p3"), JSON(20)))
    }

    /// `Number(true)` is 1 and `Number(false)` is 0; `Number(null)` is 0.
    func testRangeOperatorsConvertBooleansAndNull() {
        XCTAssertTrue(range("$gt", JSON(true), JSON(0)))
        XCTAssertTrue(range("$lt", JSON(false), JSON(1)))
        XCTAssertTrue(range("$lt", JSON.null, JSON("5")))
    }

    /// Two strings compare by UTF-16 code unit, as in JavaScript, which puts uppercase before lowercase.
    func testRangeOperatorsCompareTwoStringsByCodeUnit() {
        XCTAssertTrue(range("$lt", JSON("Zebra"), JSON("apple")))
        XCTAssertFalse(range("$gt", JSON("AZL"), JSON("alphabet")))
    }

    // MARK: - $exists reads its value with JavaScript truthiness

    private func exists(_ value: JSON, present: Bool) -> Bool {
        eval.isEvalCondition(attributes: present ? JSON(["v": 1]) : JSON([:]), conditionObj: JSON(["v": ["$exists": value]]))
    }

    func testExistsBooleanValuesAreUnchanged() {
        XCTAssertTrue(exists(true, present: true))
        XCTAssertFalse(exists(true, present: false))
        XCTAssertTrue(exists(false, present: false))
        XCTAssertFalse(exists(false, present: true))
    }

    /// A falsy value — `0`, `""`, `null` — asks for an absent attribute, like `false`.
    func testExistsFalsyValuesAskForAnAbsentAttribute() {
        for value in [JSON(0), JSON(""), JSON.null] {
            XCTAssertTrue(exists(value, present: false), "$exists: \(value) on an absent attribute")
            XCTAssertFalse(exists(value, present: true), "$exists: \(value) on a present attribute")
        }
    }

    /// Any other value asks for a present attribute. That includes the string "false", which is a
    /// non-empty string and therefore truthy in JavaScript.
    func testExistsTruthyValuesAskForAPresentAttribute() {
        for value in [JSON(1), JSON(-1), JSON("yes"), JSON("false"), JSON([Any]()), JSON([String: Any]())] {
            XCTAssertTrue(exists(value, present: true), "$exists: \(value) on a present attribute")
            XCTAssertFalse(exists(value, present: false), "$exists: \(value) on an absent attribute")
        }
    }

    func testExistsTreatsAStoredNullAsAbsent() {
        let attributes = JSON(parseJSON: #"{"v": null}"#)
        XCTAssertFalse(eval.isEvalCondition(attributes: attributes, conditionObj: JSON(["v": ["$exists": true]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attributes, conditionObj: JSON(["v": ["$exists": false]])))
    }

    // MARK: - $eq / $ne with array and object operands

    /// Both operators reach an array attribute or an array condition instead of falling through to
    /// false for both, which broke the negation.
    func testEqNeAreANegationForArrayOperands() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON([1]), conditionValue: JSON("x")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON([1]), conditionValue: JSON("x")))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON("x"), conditionValue: JSON(["x"])))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON("x"), conditionValue: JSON(["x"])))
    }

    /// The reference SDK's `===` is reference identity for arrays and objects, and a condition and an
    /// attribute are decoded separately, so equal contents are still not `$eq`.
    func testEqNeUseIdentityForCollectionsLikeTheReference() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON([1]), conditionValue: JSON([1])))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON([1]), conditionValue: JSON([1])))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$eq", attributeValue: JSON(["k": 1]), conditionValue: JSON(["k": 1])))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$ne", attributeValue: JSON(["k": 1]), conditionValue: JSON(["k": 1])))
    }

    /// Plain equality is not an operator and keeps comparing contents.
    func testPlainEqualityStillComparesArrayContents() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["tags": ["a"]]), conditionObj: JSON(["tags": ["a"]])))
    }

    func testEqNeWithAbsentAttribute() {
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON([:]), conditionObj: JSON(["v": ["$eq": "x"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON([:]), conditionObj: JSON(["v": ["$ne": "x"]])))
    }

    // MARK: - Plain equality converts like the reference

    /// Plain equality converts the attribute to the condition's type, as the reference SDK does:
    /// `value + "" === condition`, `value * 1 === condition`, `!!value === condition`. The shared
    /// spec fixtures only pair different types where the answer is false, so this went unnoticed.
    func testPlainEqualityConvertsToAStringCondition() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["id": 25]), conditionObj: JSON(["id": "25"])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["flag": true]), conditionObj: JSON(["flag": "true"])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["other": "x"]), conditionObj: JSON(["c": "null"])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["other": "x"]), conditionObj: JSON(["c": "US"])))
    }

    func testPlainEqualityConvertsToANumberCondition() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["age": "25"]), conditionObj: JSON(["age": 25])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["age": " 25 "]), conditionObj: JSON(["age": 25])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["n": true]), conditionObj: JSON(["n": 1])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["other": "x"]), conditionObj: JSON(["n": 0])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["age": "abc"]), conditionObj: JSON(["age": 25])))
    }

    func testPlainEqualityConvertsToABooleanCondition() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["beta": 1]), conditionObj: JSON(["beta": true])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["beta": "x"]), conditionObj: JSON(["beta": true])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["beta": 0]), conditionObj: JSON(["beta": false])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["beta": ""]), conditionObj: JSON(["beta": false])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["beta": 0]), conditionObj: JSON(["beta": true])))
        // `value !== null` comes first, so an absent attribute is never false-equal
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["other": "x"]), conditionObj: JSON(["beta": false])))
    }

    /// An array or object attribute converts too: `["x"] + ""` is `"x"`, `[5] * 1` is 5, and an
    /// object's text is `"[object Object]"`.
    func testPlainEqualityConvertsArrayAndObjectAttributes() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["t": ["x"]]), conditionObj: JSON(["t": "x"])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["t": ["y"]]), conditionObj: JSON(["t": "x"])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["t": [5]]), conditionObj: JSON(["t": 5])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["t": ["k": 5]]), conditionObj: JSON(["t": 5])))
        XCTAssertFalse(eval.isEvalCondition(attributes: JSON(["t": ["k": "x"]]), conditionObj: JSON(["t": "x"])))
    }

    // MARK: - $lt / $gt with string attributes

    func testLtWithStrings() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("apple"), conditionValue: JSON("banana")))
    }

    func testGtWithStrings() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$gt", attributeValue: JSON("banana"), conditionValue: JSON("apple")))
    }

    /// Two strings compare as text in JavaScript even when both look numeric, so `"3" < "10"` is false
    /// ("3" sorts after "1"). A numeric string against a number is compared as a number.
    func testLtWithStringNumbers() {
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("3"), conditionValue: JSON("10")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("10"), conditionValue: JSON("9")))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$lt", attributeValue: JSON("3"), conditionValue: JSON(10)))
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

    /// A null element is skipped, like the reference SDK: an array that merely contains a null no
    /// longer satisfies a negation-flavoured body.
    func testElemMatchSkipsNullElements() {
        let withNull = JSON(parseJSON: #"[null]"#)
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: withNull, conditionValue: JSON(["$ne": "x"])))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: withNull, conditionValue: JSON(["$nin": ["x"]])))
        XCTAssertFalse(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: withNull, conditionValue: JSON(["$exists": false])))
        // A present element alongside the null is still tested
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: JSON(parseJSON: #"[null, "y"]"#), conditionValue: JSON(["$ne": "x"])))
    }

    /// Falsy-but-present members are valid values and must still be tested.
    func testElemMatchStillTestsFalsyElements() {
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: JSON([0]), conditionValue: JSON(["$eq": 0])))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: JSON([false]), conditionValue: JSON(["$eq": false])))
        XCTAssertTrue(eval.isEvalOperatorCondition(operatorKey: "$elemMatch", attributeValue: JSON([""]), conditionValue: JSON(["$eq": ""])))
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

    private func regex(_ attributes: String, _ condition: String) -> Bool {
        eval.isEvalCondition(attributes: JSON(parseJSON: attributes), conditionObj: JSON(parseJSON: condition))
    }

    /// An array is matched as `Array.prototype.join` renders it, as in the reference SDK, and both
    /// polarities agree on that text.
    func testRegexMatchesAnArrayAsItsJoinedText() {
        let tags = #"{"v": ["internal", "beta"]}"#
        XCTAssertTrue(regex(tags, #"{"v": {"$regex": "^internal"}}"#))
        XCTAssertFalse(regex(tags, #"{"v": {"$notRegex": "^internal"}}"#))
        XCTAssertFalse(regex(tags, #"{"v": {"$not": {"$regex": "^internal"}}}"#))
        // The joined text starts with the first element only
        XCTAssertFalse(regex(tags, #"{"v": {"$regex": "^beta"}}"#))
        XCTAssertTrue(regex(tags, #"{"v": {"$notRegex": "^beta"}}"#))
    }

    /// `join` renders a null element as empty and flattens a nested array into the same text.
    func testRegexRendersArrayElementsAsJavaScriptJoinsThem() {
        XCTAssertTrue(regex(#"{"v": [1, null, "a"]}"#, #"{"v": {"$regex": "^1,,a$"}}"#))
        XCTAssertTrue(regex(#"{"v": [[1, 2], 3]}"#, #"{"v": {"$regex": "^1,2,3$"}}"#))
        XCTAssertTrue(regex(#"{"v": [10.0, true]}"#, #"{"v": {"$regex": "^10,true$"}}"#))
    }

    func testRegexMatchesAnObjectAsObjectText() {
        let object = #"{"v": {"k": "v"}}"#
        XCTAssertTrue(regex(object, #"{"v": {"$regex": "^\\[object Object\\]$"}}"#))
        XCTAssertFalse(regex(object, #"{"v": {"$regex": "k"}}"#))
    }

    func testRegexMatchesNumbersAndBooleansAsText() {
        XCTAssertTrue(regex(#"{"v": 10.0}"#, #"{"v": {"$regex": "^10$"}}"#))
        XCTAssertTrue(regex(#"{"v": 1.5}"#, #"{"v": {"$regex": "^1\\.5$"}}"#))
        XCTAssertTrue(regex(#"{"v": true}"#, #"{"v": {"$regex": "^true$"}}"#))
    }

    /// An absent or null attribute has no text: it matches no pattern — not even one that matches the
    /// empty string — and therefore does-not-match every one. It is deliberately not rendered as the
    /// text "null" either, which would let a pattern like `ull` match a user without the attribute.
    func testRegexNeverMatchesAnAbsentOrNullAttribute() {
        for attributes in [#"{}"#, #"{"v": null}"#] {
            XCTAssertFalse(regex(attributes, #"{"v": {"$regex": "^$"}}"#))
            XCTAssertFalse(regex(attributes, #"{"v": {"$regex": ".*"}}"#))
            XCTAssertFalse(regex(attributes, #"{"v": {"$regex": "ull"}}"#))
            XCTAssertTrue(regex(attributes, #"{"v": {"$notRegex": "corp"}}"#))
            XCTAssertTrue(regex(attributes, #"{"v": {"$notRegexi": "CORP"}}"#))
        }
    }

    /// An unusable pattern fails both polarities, as the reference SDK's try/catch does; a numeric
    /// pattern is no longer read as its text.
    func testRegexWithAnUnusablePatternFailsBothPolarities() {
        XCTAssertFalse(regex(#"{"v": "123"}"#, #"{"v": {"$regex": 12}}"#))
        XCTAssertFalse(regex(#"{"v": "123"}"#, #"{"v": {"$notRegex": 12}}"#))
        XCTAssertFalse(regex(#"{"v": "a"}"#, #"{"v": {"$regex": "("}}"#))
        XCTAssertFalse(regex(#"{"v": "a"}"#, #"{"v": {"$notRegex": "("}}"#))
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

    func testVersionOperatorCoercesNumericAttribute() {
        let attrs = JSON(["version": 2])
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$vgt": "1.0.0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: attrs, conditionObj: JSON(["version": ["$veq": 2]])))
    }

    /// An absent, boolean or collection attribute is treated as version "0" rather than failing outright
    func testVersionOperatorWithNonVersionAttribute() {
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON([:]), conditionObj: JSON(["version": ["$vlt": "0.0.1"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["version": true]), conditionObj: JSON(["version": ["$veq": "0"]])))
        XCTAssertTrue(eval.isEvalCondition(attributes: JSON(["version": ["1.0.0"]]), conditionObj: JSON(["version": ["$veq": "0"]])))
    }
}
