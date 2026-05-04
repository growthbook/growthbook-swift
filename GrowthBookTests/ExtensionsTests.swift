import XCTest
@testable import GrowthBook

class ExtensionsTests: XCTestCase {

    // MARK: - Float.roundTo

    func testRoundToTwoDecimalPlaces() {
        XCTAssertEqual(Float(0.12345).roundTo(numFractionDigits: 2), 0.12, accuracy: 0.0001)
    }

    func testRoundToFourDecimalPlaces() {
        XCTAssertEqual(Float(0.123456).roundTo(numFractionDigits: 4), 0.1235, accuracy: 0.00001)
    }

    func testRoundToZeroDecimalPlaces() {
        XCTAssertEqual(Float(3.7).roundTo(numFractionDigits: 0), 4.0, accuracy: 0.0001)
    }

    func testRoundToNegativeNumber() {
        XCTAssertEqual(Float(-0.556).roundTo(numFractionDigits: 2), -0.56, accuracy: 0.0001)
    }

    // MARK: - Sequence.sum

    func testSumInts() {
        XCTAssertEqual([1, 2, 3, 4].sum(), 10)
    }

    func testSumFloats() {
        XCTAssertEqual([0.25, 0.25, 0.5].sum(), 1.0, accuracy: 0.0001)
    }

    func testSumEmpty() {
        XCTAssertEqual([Float]().sum(), 0.0)
    }

    // MARK: - JSON.convertToArrayFloat

    func testConvertToArrayFloat() {
        let jsonArray: [JSON] = [JSON(1.5), JSON(2.5), JSON(3.0)]
        let result = JSON.convertToArrayFloat(jsonArray: jsonArray)
        XCTAssertEqual(result.count, 3)
        XCTAssertEqual(result[0], 1.5, accuracy: 0.001)
        XCTAssertEqual(result[1], 2.5, accuracy: 0.001)
        XCTAssertEqual(result[2], 3.0, accuracy: 0.001)
    }

    func testConvertToArrayFloatEmpty() {
        XCTAssertTrue(JSON.convertToArrayFloat(jsonArray: []).isEmpty)
    }

    // MARK: - JSON.convertToArrayString

    func testConvertToArrayString() {
        let jsonArray: [JSON] = [JSON("a"), JSON("b"), JSON("c")]
        let result = JSON.convertToArrayString(jsonArray: jsonArray)
        XCTAssertEqual(result, ["a", "b", "c"])
    }

    func testConvertToArrayStringEmpty() {
        XCTAssertTrue(JSON.convertToArrayString(jsonArray: []).isEmpty)
    }

    // MARK: - JSON.convertToTwoArrayFloat

    func testConvertToTwoArrayFloat() {
        let jsonArray: [JSON] = [JSON([0.0, 0.5]), JSON([0.5, 1.0])]
        let result = JSON.convertToTwoArrayFloat(jsonArray: jsonArray)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0][0], 0.0, accuracy: 0.001)
        XCTAssertEqual(result[0][1], 0.5, accuracy: 0.001)
        XCTAssertEqual(result[1][0], 0.5, accuracy: 0.001)
        XCTAssertEqual(result[1][1], 1.0, accuracy: 0.001)
    }

    func testConvertToTwoArrayFloatEmpty() {
        XCTAssertTrue(JSON.convertToTwoArrayFloat(jsonArray: []).isEmpty)
    }

    // MARK: - String.toData / Data.string

    func testStringToData() {
        let data = "hello".toData()
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 5)
    }

    func testDataToString() {
        let original = "world"
        let data = original.data(using: .utf8)!
        XCTAssertEqual(data.string(), "world")
    }

    func testStringToDataRoundtrip() {
        let original = "GrowthBook SDK"
        let result = original.toData()?.string()
        XCTAssertEqual(result, original)
    }

    func testEmptyStringToData() {
        let data = "".toData()
        XCTAssertNotNil(data)
        XCTAssertEqual(data?.count, 0)
    }

    // MARK: - String.lastPathComponent

    func testLastPathComponent() {
        XCTAssertEqual("/usr/local/bin/swift".lastPathComponent, "swift")
    }

    func testLastPathComponentNoSlash() {
        XCTAssertEqual("filename.txt".lastPathComponent, "filename.txt")
    }

    func testLastPathComponentTrailingSlash() {
        XCTAssertEqual("/path/to/dir/".lastPathComponent, "dir")
    }

    // MARK: - String.stringByDeletingPathExtension

    func testStringByDeletingPathExtension() {
        XCTAssertEqual("file.swift".stringByDeletingPathExtension, "file")
    }

    func testStringByDeletingPathExtensionNoExtension() {
        XCTAssertEqual("Makefile".stringByDeletingPathExtension, "Makefile")
    }

    func testStringByDeletingPathExtensionWithPath() {
        XCTAssertEqual("/path/to/file.txt".stringByDeletingPathExtension, "/path/to/file")
    }

    // MARK: - String.withColor

    func testWithColorAppliesEscapeSequence() {
        let result = "hello".withColor("red")
        XCTAssertTrue(result.contains("hello"))
        XCTAssertTrue(result.contains("red"))
    }

    func testWithColorNilReturnsOriginal() {
        XCTAssertEqual("hello".withColor(nil), "hello")
    }
}
