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

    // MARK: - deleteAssignments

    func testDeleteAssignmentsRemovesOnlyTheTargetedDoc() {
        let docA = StickyAssignmentsDocument(attributeName: "id",       attributeValue: "user-del",   assignments: ["exp__0": "a"])
        let docB = StickyAssignmentsDocument(attributeName: "deviceId", attributeValue: "device-del", assignments: ["exp__0": "b"])

        let s1 = expectation(description: "save A"); service.saveAssignments(doc: docA) { _ in s1.fulfill() }
        let s2 = expectation(description: "save B"); service.saveAssignments(doc: docB) { _ in s2.fulfill() }
        waitForExpectations(timeout: 1)

        let del = expectation(description: "delete A")
        service.deleteAssignments(attributeName: "id", attributeValue: "user-del") { error in
            XCTAssertNil(error)
            del.fulfill()
        }
        waitForExpectations(timeout: 1)

        let get = expectation(description: "getAll after delete")
        service.getAllAssignments(attributes: ["id": "user-del", "deviceId": "device-del"]) { docs, _ in
            XCTAssertNil(docs?["id||user-del"], "deleted doc should be gone")
            XCTAssertNotNil(docs?["deviceId||device-del"], "untouched doc should survive")
            get.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testDeleteAssignmentsForUnknownKeyIsNotAnError() {
        let exp = expectation(description: "delete missing")
        service.deleteAssignments(attributeName: "id", attributeValue: "never-saved") { error in
            XCTAssertNil(error)
            exp.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    // MARK: - clearAllAssignments

    func testClearAllAssignmentsRemovesEveryDoc() {
        let docA = StickyAssignmentsDocument(attributeName: "id",       attributeValue: "user-clear",   assignments: ["exp__0": "a"])
        let docB = StickyAssignmentsDocument(attributeName: "deviceId", attributeValue: "device-clear", assignments: ["exp__0": "b"])

        let s1 = expectation(description: "save A"); service.saveAssignments(doc: docA) { _ in s1.fulfill() }
        let s2 = expectation(description: "save B"); service.saveAssignments(doc: docB) { _ in s2.fulfill() }
        waitForExpectations(timeout: 1)

        let clear = expectation(description: "clear all")
        service.clearAllAssignments { error in
            XCTAssertNil(error)
            clear.fulfill()
        }
        waitForExpectations(timeout: 1)

        let get = expectation(description: "getAll after clear")
        service.getAllAssignments(attributes: ["id": "user-clear", "deviceId": "device-clear"]) { docs, _ in
            XCTAssertTrue(docs?.isEmpty ?? true)
            get.fulfill()
        }
        waitForExpectations(timeout: 1)
    }

    func testClearAllAssignmentsLeavesOtherPrefixesIntact() {
        let otherService = StickyBucketService(prefix: "other_prefix_\(Int.random(in: 100_000...999_999))__")
        let doc = StickyAssignmentsDocument(attributeName: "id", attributeValue: "kept-user", assignments: ["exp__0": "variant"])

        let s1 = expectation(description: "save in service"); service.saveAssignments(doc: doc) { _ in s1.fulfill() }
        let s2 = expectation(description: "save in other");   otherService.saveAssignments(doc: doc) { _ in s2.fulfill() }
        waitForExpectations(timeout: 1)

        let clear = expectation(description: "clear all")
        service.clearAllAssignments { _ in clear.fulfill() }
        waitForExpectations(timeout: 1)

        let get = expectation(description: "other prefix survives")
        otherService.getAssignments(attributeName: "id", attributeValue: "kept-user") { retrieved, _ in
            XCTAssertNotNil(retrieved, "clearing one prefix must not touch documents of another")
            get.fulfill()
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
