//
//  StickyBucketCacheTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/24/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class StickyBucketCacheTests: XCTestCase {
    typealias SUT = StickyBucketFileStorageCache

    let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/test"))

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testGetAssignment() throws {
        let storage = KeyedStorageInterfaceMock<StickyAssignmentsDocument>()
        let key1: String = "key1"
        let assignment: StickyAssignmentsDocument = .init(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])
        storage.storage[key1] = assignment

        let sut: SUT = .init(
            directoryURL: directoryURL,
            storage: storage
        )

        try XCTAssertEqual(sut.stickyAssignment(for: key1), assignment)
        XCTAssertTrue(storage.didCallValue)
    }

    func testSetAssignments() throws {
        let storage = KeyedStorageInterfaceMock<StickyAssignmentsDocument>()
        let key1: String = "key1"
        let assignment: StickyAssignmentsDocument = .init(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])

        let sut: SUT = .init(
            directoryURL: directoryURL,
            storage: storage
        )
        try XCTAssertNil(sut.stickyAssignment(for: key1))

        try sut.updateStickyAssignment(assignment, for: key1)

        try XCTAssertEqual(sut.stickyAssignment(for: key1), assignment)
        XCTAssertTrue(storage.didCallUpdateValue)
        XCTAssertEqual(storage.updateValueCalls.first?.0, assignment)
        XCTAssertEqual(storage.updateValueCalls.first?.1, key1)
    }

    func testClearCache() throws {
        let storage = KeyedStorageInterfaceMock<StickyAssignmentsDocument>()
        let key1: String = "key1"
        let assignment: StickyAssignmentsDocument = .init(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])
        storage.storage[key1] = assignment

        let sut: SUT = .init(
            directoryURL: directoryURL,
            storage: storage
        )

        try sut.clearCache()

        try XCTAssertNil(sut.stickyAssignment(for: key1))
        XCTAssertTrue(storage.didCallValue)
    }

    func testFileCacheStorage() throws {
        let key1: String = "key1"
        let assignment: StickyAssignmentsDocument = .init(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])
        let fileManager: FileManager = .default

        let sut: SUT = .withFileCacheStorage(directoryURL: directoryURL, fileManager: fileManager)

        try sut.updateStickyAssignment(assignment, for: key1)
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(key1, isDirectory: false).path))

        try sut.clearCache()

        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.path))
    }

    func testDeinit() throws {
        // GIVEN
        let storageMock = WeakChecker(KeyedStorageInterfaceMock<StickyAssignmentsDocument>())

        let assignment = StickyAssignmentsDocument(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])

        let sut: WeakChecker<SUT> = WeakChecker(
            .init(
                directoryURL: directoryURL,
                storage: storageMock.object
            )
        )

        let key1: String = "key1"

        try sut.object.updateStickyAssignment(assignment, for: key1)

        // WHEN
        sut.removeLink()
        storageMock.removeLink()

        // THEN
        sut.assertNil()
        storageMock.assertNil()
    }
}

class WeakChecker<Value: AnyObject> {
    private weak var weakObject: Value?
    private(set) var object: Value!

    init(_ object: Value) {
        self.weakObject = object
        self.object = object
    }

    func removeLink() {
        object = nil
    }

    func assertNil(_ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNil(weakObject, message(), file: file, line: line)
    }

    func assertNotNil(_ message: @autoclosure () -> String = "", file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertNotNil(weakObject, message(), file: file, line: line)
    }
}
