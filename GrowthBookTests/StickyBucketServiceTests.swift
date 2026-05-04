import XCTest
@testable import GrowthBook

class StickyBucketServiceTests: XCTestCase {

    var service: StickyBucketService!
    let testPrefix = "test_sticky_\(Int.random(in: 100_000...999_999))__"

    override func setUp() {
        super.setUp()
        service = StickyBucketService(prefix: testPrefix)
    }

    // MARK: - getAssignments returns nil when nothing is saved

    func testGetAssignmentsReturnsNilForUnknownKey() {
        let expectation = expectation(description: "completion called")
        service.getAssignments(attributeName: "id", attributeValue: "nonexistent-user") { doc, error in
            XCTAssertNil(doc)
            XCTAssertNil(error)
            expectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - saveAssignments → getAssignments round-trip

    func testSaveAndGetAssignments() {
        let doc = StickyAssignmentsDocument(
            attributeName: "id",
            attributeValue: "user-abc",
            assignments: ["exp-1__0": "control", "exp-2__0": "variant"]
        )

        let saveExpectation = expectation(description: "save completed")
        service.saveAssignments(doc: doc) { _ in saveExpectation.fulfill() }
        waitForExpectations(timeout: 1)

        let getExpectation = expectation(description: "get completed")
        service.getAssignments(attributeName: "id", attributeValue: "user-abc") { retrieved, error in
            XCTAssertNotNil(retrieved)
            XCTAssertNil(error)
            XCTAssertEqual(retrieved?.attributeName, "id")
            XCTAssertEqual(retrieved?.attributeValue, "user-abc")
            XCTAssertEqual(retrieved?.assignments["exp-1__0"], "control")
            XCTAssertEqual(retrieved?.assignments["exp-2__0"], "variant")
            getExpectation.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - saveAssignments overwrites existing doc

    func testSaveAssignmentsOverwritesPreviousDoc() {
        let original = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-xyz",
            assignments: ["exp-1__0": "control"]
        )
        let updated = StickyAssignmentsDocument(
            attributeName: "id", attributeValue: "user-xyz",
            assignments: ["exp-1__0": "variant"]
        )

        let save1 = expectation(description: "first save")
        service.saveAssignments(doc: original) { _ in save1.fulfill() }
        waitForExpectations(timeout: 1)

        let save2 = expectation(description: "second save")
        service.saveAssignments(doc: updated) { _ in save2.fulfill() }
        waitForExpectations(timeout: 1)

        let get = expectation(description: "get")
        service.getAssignments(attributeName: "id", attributeValue: "user-xyz") { retrieved, _ in
            XCTAssertEqual(retrieved?.assignments["exp-1__0"], "variant")
            get.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - getAllAssignments

    func testGetAllAssignmentsReturnsOnlyMatchingDocs() {
        let docA = StickyAssignmentsDocument(attributeName: "id",       attributeValue: "user-1",   assignments: ["exp__0": "a"])
        let docB = StickyAssignmentsDocument(attributeName: "deviceId", attributeValue: "device-1", assignments: ["exp__0": "b"])

        let s1 = expectation(description: "save A"); service.saveAssignments(doc: docA) { _ in s1.fulfill() }
        let s2 = expectation(description: "save B"); service.saveAssignments(doc: docB) { _ in s2.fulfill() }
        waitForExpectations(timeout: 1)

        let getAllExp = expectation(description: "getAll")
        service.getAllAssignments(attributes: ["id": "user-1", "deviceId": "device-1"]) { docs, error in
            XCTAssertNil(error)
            XCTAssertEqual(docs?.count, 2)
            XCTAssertNotNil(docs?["id||user-1"])
            XCTAssertNotNil(docs?["deviceId||device-1"])
            getAllExp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testGetAllAssignmentsReturnsEmptyWhenNothingSaved() {
        let exp = expectation(description: "getAll empty")
        service.getAllAssignments(attributes: ["id": "unknown-user"]) { docs, error in
            XCTAssertNil(error)
            XCTAssertTrue(docs?.isEmpty ?? true)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - Different prefixes are isolated

    func testDifferentPrefixesDoNotShareData() {
        let serviceA = StickyBucketService(prefix: "prefix_a__")
        let serviceB = StickyBucketService(prefix: "prefix_b__")

        let doc = StickyAssignmentsDocument(attributeName: "id", attributeValue: "shared-user", assignments: ["exp__0": "variant"])

        let saveExp = expectation(description: "save in A")
        serviceA.saveAssignments(doc: doc) { _ in saveExp.fulfill() }
        waitForExpectations(timeout: 1)

        let getExp = expectation(description: "get from B")
        serviceB.getAssignments(attributeName: "id", attributeValue: "shared-user") { retrieved, _ in
            XCTAssertNil(retrieved, "prefix_b should not see data saved under prefix_a")
            getExp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }
}
