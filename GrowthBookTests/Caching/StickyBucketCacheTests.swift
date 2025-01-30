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

        let sut = StickyBucketFileStorageCache(
            directoryURL: directoryURL,
            storage: storage
        )

        try XCTAssertEqual(sut.stickyAssignment(for: key1), assignment)
        XCTAssertTrue(storage.didCallValue)
    }

    func testSetSavedGroups() throws {
        let storage = KeyedStorageInterfaceMock<StickyAssignmentsDocument>()
        let key1: String = "key1"
        let assignment: StickyAssignmentsDocument = .init(attributeName: "a", attributeValue: "b", assignments: ["c": "d"])

        let sut = StickyBucketFileStorageCache(
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

        let sut = StickyBucketFileStorageCache(
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

        let sut = StickyBucketFileStorageCache.withFileCacheStorage(directoryURL: directoryURL, fileManager: fileManager)

        try sut.updateStickyAssignment(assignment, for: key1)
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.path))
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(key1, isDirectory: false).path))

        try sut.clearCache()

        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.path))
    }
}
