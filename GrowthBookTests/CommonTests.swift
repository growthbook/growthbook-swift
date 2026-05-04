import XCTest
@testable import GrowthBook

class CommonTests: XCTestCase {

    // MARK: - fnv1 / fnv1a

    func testFnv1aProducesKnownHash() {
        // FNV-1a of empty string with 32-bit basis
        let result = Common.fnv1a([UInt8](), offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        XCTAssertEqual(result, Common.offsetBasis32, "FNV-1a of empty input equals the offset basis")
    }

    func testFnv1ProducesKnownHash() {
        let result = Common.fnv1([UInt8](), offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        XCTAssertEqual(result, Common.offsetBasis32)
    }

    func testFnv1aIsDifferentFromFnv1ForSameInput() {
        let bytes: [UInt8] = Array("hello".utf8)
        let fnv1result  = Common.fnv1(bytes,  offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        let fnv1aResult = Common.fnv1a(bytes, offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        XCTAssertNotEqual(fnv1result, fnv1aResult)
    }

    func testFnv1aIsDeterministic() {
        let bytes: [UInt8] = Array("deterministic".utf8)
        let first  = Common.fnv1a(bytes, offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        let second = Common.fnv1a(bytes, offsetBasis: Common.offsetBasis32, prime: Common.prime32)
        XCTAssertEqual(first, second)
    }

    func testFnv1a64BitProducesLargerValue() {
        let bytes: [UInt8] = Array("test".utf8)
        let result64: UInt64 = Common.fnv1a(bytes, offsetBasis: Common.offsetBasis64, prime: Common.prime64)
        XCTAssertGreaterThan(result64, 0)
    }

    // MARK: - isEqual

    func testIsEqualStrings() {
        XCTAssertTrue(Common.isEqual("hello", "hello"))
        XCTAssertFalse(Common.isEqual("hello", "world"))
    }

    func testIsEqualInts() {
        XCTAssertTrue(Common.isEqual(42, 42))
        XCTAssertFalse(Common.isEqual(1, 2))
    }

    // MARK: - isIn (case-sensitive)

    func testIsInStringFound() {
        XCTAssertTrue(Common.isIn(actual: "b", expected: ["a", "b", "c"]))
    }

    func testIsInStringNotFound() {
        XCTAssertFalse(Common.isIn(actual: "z", expected: ["a", "b", "c"]))
    }

    func testIsInIntFound() {
        XCTAssertTrue(Common.isIn(actual: 2, expected: [1, 2, 3]))
    }

    func testIsInIntNotFound() {
        XCTAssertFalse(Common.isIn(actual: 99, expected: [1, 2, 3]))
    }

    func testIsInArrayActualOverlapsExpected() {
        XCTAssertTrue(Common.isIn(actual: ["x", "b"], expected: ["a", "b", "c"]))
    }

    func testIsInArrayActualNoOverlap() {
        XCTAssertFalse(Common.isIn(actual: ["x", "y"], expected: ["a", "b", "c"]))
    }

    func testIsInJSONStringFound() {
        let jsonExpected: [JSON] = [JSON("alpha"), JSON("beta"), JSON("gamma")]
        XCTAssertTrue(Common.isIn(actual: JSON("beta"), expected: jsonExpected))
    }

    func testIsInJSONStringNotFound() {
        let jsonExpected: [JSON] = [JSON("alpha"), JSON("beta")]
        XCTAssertFalse(Common.isIn(actual: JSON("delta"), expected: jsonExpected))
    }

    func testIsInJSONArrayActualOverlaps() {
        let jsonExpected: [JSON] = [JSON("a"), JSON("b"), JSON("c")]
        let actual = JSON(["b", "x"])
        XCTAssertTrue(Common.isIn(actual: actual, expected: jsonExpected))
    }

    // MARK: - isIn (case-insensitive)

    func testIsInCaseInsensitiveStringMatch() {
        let expected: [JSON] = [JSON("hello"), JSON("world")]
        XCTAssertTrue(Common.isIn(actual: JSON("HELLO"), expected: expected, insensitive: true))
    }

    func testIsInCaseInsensitiveStringNoMatch() {
        let expected: [JSON] = [JSON("hello"), JSON("world")]
        XCTAssertFalse(Common.isIn(actual: JSON("foo"), expected: expected, insensitive: true))
    }

    func testIsInCaseInsensitivePlainStringActual() {
        let expected: [JSON] = [JSON("Apple"), JSON("Banana")]
        XCTAssertTrue(Common.isIn(actual: "APPLE", expected: expected, insensitive: true))
    }

    func testIsInCaseInsensitiveJSONArrayActual() {
        let expected: [JSON] = [JSON("Cat"), JSON("Dog")]
        let actual = JSON(["cat", "fish"])
        XCTAssertTrue(Common.isIn(actual: actual, expected: expected, insensitive: true))
    }

    func testIsInCaseInsensitiveJSONArrayNoMatch() {
        let expected: [JSON] = [JSON("Cat"), JSON("Dog")]
        let actual = JSON(["fish", "bird"])
        XCTAssertFalse(Common.isIn(actual: actual, expected: expected, insensitive: true))
    }

    // MARK: - isInAll

    func testIsInAllEveryExpectedItemMatchesSomething() {
        let actual = JSON(["a", "b", "c"])
        let expected: [JSON] = [JSON("a"), JSON("b")]
        let result = Common.isInAll(actual: actual, expected: expected, savedGroups: nil, insensitive: false) { _, _, _ in true }
        XCTAssertTrue(result)
    }

    func testIsInAllReturnsFalseWhenOneExpectedItemHasNoMatch() {
        let actual = JSON(["a"])
        let expected: [JSON] = [JSON("a"), JSON("b")]
        let result = Common.isInAll(actual: actual, expected: expected, savedGroups: nil, insensitive: false) { expectedItem, actualItem, _ in
            expectedItem == actualItem
        }
        XCTAssertFalse(result)
    }

    func testIsInAllReturnsFalseForNonArray() {
        let actual = JSON("not-an-array")
        let expected: [JSON] = [JSON("anything")]
        let result = Common.isInAll(actual: actual, expected: expected, savedGroups: nil, insensitive: false) { _, _, _ in true }
        XCTAssertFalse(result)
    }

    func testIsInAllReturnsTrueForEmptyExpected() {
        let actual = JSON(["a", "b"])
        let result = Common.isInAll(actual: actual, expected: [], savedGroups: nil, insensitive: false) { _, _, _ in false }
        XCTAssertTrue(result)
    }
}
