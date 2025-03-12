//
//  SavedGroupsCacheTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/24/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class SavedGroupsCacheTests: XCTestCase {
    typealias SUT = SavedGroupsCache
    func testGetSavedGroups() throws {
        let storage = DataStorageInterfaceMock<JSON>()
        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)
        storage.underlyingValue = .init(savedGroups)

        let sut: SUT = SUT(storage: storage)

        try XCTAssertEqual(sut.savedGroups(), savedGroups)
        XCTAssertTrue(storage.didCallValue)
    }

    func testSetSavedGroups() throws {
        let storage = DataStorageInterfaceMock<JSON>()

        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)

        let sut: SUT = SUT(storage: storage)

        try sut.updateSavedGroups(savedGroups)

        XCTAssertTrue(storage.didCallUpdateValue)
        XCTAssertEqual(storage.updateValueCalls, [savedGroups])
        try XCTAssertEqual(sut.savedGroups(), savedGroups)
    }

    func testClearCache() throws {
        let storage = DataStorageInterfaceMock<JSON>()
        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)
        storage.underlyingValue = .init(savedGroups)

        let sut: SUT = SUT(storage: storage)
        try XCTAssertNotNil(sut.savedGroups())

        try sut.clearCache()

        try XCTAssertNil(sut.savedGroups())
        XCTAssertTrue(storage.didCallReset)
    }

    func testDeinit() throws {
        let storage = WeakChecker(DataStorageInterfaceMock<JSON>())

        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)

        let sut: WeakChecker<SUT> = WeakChecker(SUT(storage: storage.object))

        try sut.object.updateSavedGroups(savedGroups)

        // WHEN
        sut.removeLink()
        storage.removeLink()

        // THEN
        sut.assertNil()
        storage.assertNil()
    }
}
