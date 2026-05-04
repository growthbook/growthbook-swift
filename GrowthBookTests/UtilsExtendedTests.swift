import XCTest
@testable import GrowthBook

class UtilsExtendedTests: XCTestCase {

    // MARK: - hash edge cases

    func testHashVersionOneReturnsBetweenZeroAndOne() {
        let result = Utils.hash(seed: "test", value: "user-123", version: 1)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!, 0.0)
        XCTAssertLessThanOrEqual(result!, 1.0)
    }

    func testHashVersionTwoReturnsBetweenZeroAndOne() {
        let result = Utils.hash(seed: "test", value: "user-123", version: 2)
        XCTAssertNotNil(result)
        XCTAssertGreaterThanOrEqual(result!, 0.0)
        XCTAssertLessThanOrEqual(result!, 1.0)
    }

    func testHashVersionTwoDifferentFromVersionOne() {
        let v1 = Utils.hash(seed: "seed", value: "abc", version: 1)
        let v2 = Utils.hash(seed: "seed", value: "abc", version: 2)
        XCTAssertNotNil(v1)
        XCTAssertNotNil(v2)
        XCTAssertNotEqual(v1, v2)
    }

    func testHashUnknownVersionReturnsNil() {
        XCTAssertNil(Utils.hash(seed: "seed", value: "value", version: 99))
        XCTAssertNil(Utils.hash(seed: "seed", value: "value", version: 0))
    }

    func testHashIsDeterministic() {
        let a = Utils.hash(seed: "s", value: "v", version: 2)
        let b = Utils.hash(seed: "s", value: "v", version: 2)
        XCTAssertEqual(a, b)
    }

    // MARK: - isFilteredOut

    func testIsFilteredOutReturnsFalseWhenHashInRange() {
        let attributes = JSON(["id": "user-1"])
        let filter = Filter(
            attribute: "id",
            seed: "my-seed",
            hashVersion: 2,
            ranges: [BucketRange(number1: 0.0, number2: 1.0)],
            fallbackAttribute: nil
        )
        XCTAssertFalse(Utils.isFilteredOut(filters: [filter], attributes: attributes))
    }

    func testIsFilteredOutReturnsTrueWhenHashOutsideAllRanges() {
        let attributes = JSON(["id": "user-1"])
        let filter = Filter(
            attribute: "id",
            seed: "my-seed",
            hashVersion: 2,
            ranges: [BucketRange(number1: 0.0, number2: 0.0)],
            fallbackAttribute: nil
        )
        XCTAssertTrue(Utils.isFilteredOut(filters: [filter], attributes: attributes))
    }

    func testIsFilteredOutReturnsFalseForEmptyFilters() {
        let attributes = JSON(["id": "anything"])
        XCTAssertFalse(Utils.isFilteredOut(filters: [], attributes: attributes))
    }

    // MARK: - isIncludedInRollout

    func testIsIncludedInRolloutBothNilReturnsTrue() {
        XCTAssertTrue(Utils.isIncludedInRollout(
            attributes: JSON(["id": "user"]),
            seed: "seed",
            hashAttribute: "id",
            fallbackAttribute: nil,
            range: nil,
            coverage: nil,
            hashVersion: 1
        ))
    }

    func testIsIncludedInRolloutCoverageZeroReturnsFalse() {
        XCTAssertFalse(Utils.isIncludedInRollout(
            attributes: JSON(["id": "user"]),
            seed: "seed",
            hashAttribute: "id",
            fallbackAttribute: nil,
            range: nil,
            coverage: 0,
            hashVersion: 1
        ))
    }

    func testIsIncludedInRolloutFullCoverageIncludesAll() {
        for i in 0..<20 {
            let included = Utils.isIncludedInRollout(
                attributes: JSON(["id": "user-\(i)"]),
                seed: "seed",
                hashAttribute: "id",
                fallbackAttribute: nil,
                range: nil,
                coverage: 1.0,
                hashVersion: 1
            )
            XCTAssertTrue(included, "user-\(i) should be included at coverage 1.0")
        }
    }

    func testIsIncludedInRolloutRangeIncludesHashInRange() {
        XCTAssertTrue(Utils.isIncludedInRollout(
            attributes: JSON(["id": "user"]),
            seed: "seed",
            hashAttribute: "id",
            fallbackAttribute: nil,
            range: BucketRange(number1: 0.0, number2: 1.0),
            coverage: nil,
            hashVersion: 1
        ))
    }

    func testIsIncludedInRolloutRangeExcludesHashOutOfRange() {
        XCTAssertFalse(Utils.isIncludedInRollout(
            attributes: JSON(["id": "user"]),
            seed: "seed",
            hashAttribute: "id",
            fallbackAttribute: nil,
            range: BucketRange(number1: 0.0, number2: 0.0),
            coverage: nil,
            hashVersion: 1
        ))
    }

    func testIsIncludedInRolloutUsesFallbackWhenAttributeMissing() {
        let attrs = JSON(["deviceId": "device-42"])
        let withFallback = Utils.isIncludedInRollout(
            attributes: attrs,
            seed: "seed",
            hashAttribute: "id",
            fallbackAttribute: "deviceId",
            range: nil,
            coverage: 1.0,
            hashVersion: 1
        )
        XCTAssertTrue(withFallback)
    }

    // MARK: - getHashAttribute

    func testGetHashAttributePrimaryHit() {
        let attrs = JSON(["id": "user-99"])
        let result = Utils.getHashAttribute(attr: "id", attributes: attrs)
        XCTAssertEqual(result.hashAttribute, "id")
        XCTAssertEqual(result.hashValue, "user-99")
    }

    func testGetHashAttributeFallsBackWhenPrimaryMissing() {
        let attrs = JSON(["deviceId": "device-77"])
        let result = Utils.getHashAttribute(attr: "id", fallback: "deviceId", attributes: attrs)
        XCTAssertEqual(result.hashAttribute, "deviceId")
        XCTAssertEqual(result.hashValue, "device-77")
    }

    func testGetHashAttributeDefaultsToIdKey() {
        let attrs = JSON(["id": "default-user"])
        let result = Utils.getHashAttribute(attr: nil, attributes: attrs)
        XCTAssertEqual(result.hashAttribute, "id")
        XCTAssertEqual(result.hashValue, "default-user")
    }

    func testGetHashAttributeReturnsEmptyWhenBothMissing() {
        let attrs = JSON(["email": "user@example.com"])
        let result = Utils.getHashAttribute(attr: "id", fallback: "deviceId", attributes: attrs)
        XCTAssertEqual(result.hashValue, "")
    }

    // MARK: - parseQueryString

    func testParseQueryStringBasic() {
        let result = Utils.parseQueryString("foo=bar&baz=qux")
        XCTAssertEqual(result["foo"], "bar")
        XCTAssertEqual(result["baz"], "qux")
    }

    func testParseQueryStringEmpty() {
        XCTAssertTrue(Utils.parseQueryString(nil).isEmpty)
        XCTAssertTrue(Utils.parseQueryString("").isEmpty)
    }

    func testParseQueryStringWithPercentEncoding() {
        let result = Utils.parseQueryString("name=hello%20world")
        XCTAssertEqual(result["name"], "hello world")
    }

    func testParseQueryStringKeyWithoutValue() {
        let result = Utils.parseQueryString("flag=")
        XCTAssertEqual(result["flag"], "")
    }

    // MARK: - getQueryStringOverride

    func testGetQueryStringOverrideReturnsVariationIndex() {
        let result = Utils.getQueryStringOverride(id: "my-exp", urlString: "https://example.com?my-exp=1", numberOfVariations: 3)
        XCTAssertEqual(result, 1)
    }

    func testGetQueryStringOverrideReturnsNilWhenKeyAbsent() {
        let result = Utils.getQueryStringOverride(id: "other-exp", urlString: "https://example.com?my-exp=1", numberOfVariations: 3)
        XCTAssertNil(result)
    }

    func testGetQueryStringOverrideReturnsNilWhenIndexOutOfBounds() {
        let result = Utils.getQueryStringOverride(id: "my-exp", urlString: "https://example.com?my-exp=5", numberOfVariations: 3)
        XCTAssertNil(result)
    }

    func testGetQueryStringOverrideReturnsNilForInvalidURL() {
        let result = Utils.getQueryStringOverride(id: "exp", urlString: nil, numberOfVariations: 2)
        XCTAssertNil(result)
    }

    func testGetQueryStringOverrideZeroIndexAllowed() {
        let result = Utils.getQueryStringOverride(id: "exp", urlString: "https://example.com?exp=0", numberOfVariations: 2)
        XCTAssertEqual(result, 0)
    }

    // MARK: - inRange

    func testInRangeReturnsTrueForValueAtStart() {
        XCTAssertTrue(Utils.inRange(n: 0.0, range: BucketRange(number1: 0.0, number2: 0.5)))
    }

    func testInRangeReturnsFalseForValueAtEnd() {
        XCTAssertFalse(Utils.inRange(n: 0.5, range: BucketRange(number1: 0.0, number2: 0.5)))
    }

    func testInRangeReturnsFalseForValueBeforeRange() {
        XCTAssertFalse(Utils.inRange(n: -0.1, range: BucketRange(number1: 0.0, number2: 0.5)))
    }

    func testInRangeReturnsFalseForValueAfterRange() {
        XCTAssertFalse(Utils.inRange(n: 0.9, range: BucketRange(number1: 0.0, number2: 0.5)))
    }

    // MARK: - convertJsonToDouble

    func testConvertJsonToDoubleFromNumber() {
        let value = JSON(3.14)
        let result = try? XCTUnwrap(Utils.convertJsonToDouble(from: value))
        XCTAssertEqual(result ?? 0, 3.14, accuracy: 0.0001)
    }

    func testConvertJsonToDoubleFromString() {
        let value = JSON("2.718")
        let result = try? XCTUnwrap(Utils.convertJsonToDouble(from: value))
        XCTAssertEqual(result ?? 0, 2.718, accuracy: 0.0001)
    }

    func testConvertJsonToDoubleFromNil() {
        XCTAssertNil(Utils.convertJsonToDouble(from: nil))
    }

    func testConvertJsonToDoubleFromNonNumericString() {
        let value = JSON("not-a-number")
        XCTAssertNil(Utils.convertJsonToDouble(from: value))
    }
}
