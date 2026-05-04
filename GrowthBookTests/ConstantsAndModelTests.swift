import XCTest
@testable import GrowthBook

class StickyAssignmentsDocumentTests: XCTestCase {

    func testInitWithStringAssignments() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-1",
            assignments: ["exp__0": "control", "exp2__0": "variant"]
        )
        XCTAssertEqual(doc.attributeName, "id")
        XCTAssertEqual(doc.attributeValue, "user-1")
        XCTAssertEqual(doc.assignments["exp__0"], "control")
        XCTAssertEqual(doc.assignments["exp2__0"], "variant")
    }

func testCodableRoundtrip() throws {
        let original = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-99",
            assignments: ["exp__0": "control"]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(StickyAssignmentsDocument.self, from: data)
        XCTAssertEqual(decoded.attributeName, original.attributeName)
        XCTAssertEqual(decoded.attributeValue, original.attributeValue)
        XCTAssertEqual(decoded.assignments, original.assignments)
    }

    func testInitWithEmptyAssignments() {
        let empty: [String: String] = [:]
        let doc = StickyAssignmentsDocument(attributeName: "id", attributeValue: "u", assignments: empty)
        XCTAssertTrue(doc.assignments.isEmpty)
    }
}

class ConstantsTests: XCTestCase {

    // MARK: - BucketRange.init(json:)

    func testBucketRangeInitFromValidJsonArray() {
        let json = JSON([0.25, 0.75])
        let range = BucketRange(json: json)
        XCTAssertEqual(range.number1, 0.25)
        XCTAssertEqual(range.number2, 0.75)
    }

    func testBucketRangeInitFromEmptyJsonArray() {
        let json = JSON([])
        let range = BucketRange(json: json)
        XCTAssertEqual(range.number1, 0.0)
        XCTAssertEqual(range.number2, 0.0)
    }

    // MARK: - Filter.init(json:)

    func testFilterInitFromJson() {
        let json: [String: JSON] = [
            "attribute": JSON("userId"),
            "seed": JSON("my-seed"),
            "hashVersion": JSON(2),
            "ranges": JSON([[0.0, 0.5], [0.6, 1.0]])
        ]
        let filter = Filter(json: json)
        XCTAssertEqual(filter.attribute, "userId")
        XCTAssertEqual(filter.seed, "my-seed")
        XCTAssertEqual(filter.hashVersion, 2.0)
        XCTAssertEqual(filter.ranges.count, 2)
        XCTAssertEqual(filter.ranges[0].number1, 0.0)
        XCTAssertEqual(filter.ranges[0].number2, 0.5)
    }

    func testFilterInitDefaultsHashVersionToTwo() {
        let filter = Filter(json: ["seed": JSON("s")])
        XCTAssertEqual(filter.hashVersion, 2.0)
        XCTAssertEqual(filter.seed, "s")
        XCTAssertNil(filter.attribute)
        XCTAssertTrue(filter.ranges.isEmpty)
    }

    // MARK: - VariationMeta

    func testVariationMetaInitFromJson() {
        let json: [String: JSON] = [
            "key": JSON("variant-a"),
            "name": JSON("Variant A"),
            "passthrough": JSON(false)
        ]
        let meta = VariationMeta(json: json)
        XCTAssertEqual(meta.key, "variant-a")
        XCTAssertEqual(meta.name, "Variant A")
        XCTAssertEqual(meta.passthrough, false)
    }

    func testVariationMetaInitEmptyJson() {
        let meta = VariationMeta(json: [:])
        XCTAssertNil(meta.key)
        XCTAssertNil(meta.name)
        XCTAssertNil(meta.passthrough)
    }

    // MARK: - ParentConditionInterface

    func testParentConditionInterfaceInitFromJson() {
        let json: [String: JSON] = [
            "id": JSON("parent-feature"),
            "condition": JSON(["value": true]),
            "gate": JSON(true)
        ]
        let parent = ParentConditionInterface(json: json)
        XCTAssertEqual(parent.id, "parent-feature")
        XCTAssertEqual(parent.condition["value"].boolValue, true)
        XCTAssertEqual(parent.gate, true)
    }

    func testParentConditionInterfaceDefaultGateIsNil() {
        let json: [String: JSON] = ["id": JSON("feat"), "condition": JSON(["x": 1])]
        let parent = ParentConditionInterface(json: json)
        XCTAssertNil(parent.gate)
    }

    // MARK: - SDKError

    func testSDKErrorHasCorrectCode() {
        XCTAssertEqual(SDKError.failedToLoadData.code, .failedToLoadData)
        XCTAssertEqual(SDKError.failedParsedData.code, .failedParsedData)
        XCTAssertEqual(SDKError.failedMissingKey.code, .failedMissingKey)
        XCTAssertEqual(SDKError.failedEncryptedFeatures.code, .failedEncryptedFeatures)
        XCTAssertEqual(SDKError.failedToFetchData.code, .failedToFetchData)
    }

    func testSDKErrorWithUnderlyingError() {
        let underlying = NSError(domain: "test", code: 42)
        let error = SDKError.failedToFetchData(underlying)
        XCTAssertNotNil(error.underlying)
        XCTAssertEqual(error.code, .failedToFetchData)
    }
}
