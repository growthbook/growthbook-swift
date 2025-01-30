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
    func testGetSavedGroups() throws {
        let storage = DataStorageInterfaceMock<JSON>()
        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)
        storage.underlyingValue = .init(savedGroups)

        let sut = SavedGroupsCache(storage: storage)

        try XCTAssertEqual(sut.savedGroups(), savedGroups)
        XCTAssertTrue(storage.didCallValue)
    }

    func testSetSavedGroups() throws {
        let storage = DataStorageInterfaceMock<JSON>()

        let jsonRawValue: Bool = true
        let savedGroups: JSON = .init(jsonRawValue)

        let sut = SavedGroupsCache(storage: storage)

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

        let sut = SavedGroupsCache(storage: storage)
        try XCTAssertNotNil(sut.savedGroups())

        try sut.clearCache()

        try XCTAssertNil(sut.savedGroups())
        XCTAssertTrue(storage.didCallReset)
    }
}
