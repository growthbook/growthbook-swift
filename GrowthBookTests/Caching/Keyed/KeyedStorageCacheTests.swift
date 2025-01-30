//
//  KeyedStorageCacheTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/23/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class KeyedStorageInterfaceMock<Value>: KeyedStorageInterface {
    var storage: [String: Value] = [:]
    init(storage: [String : Value] = [:]) {
        self.storage = storage
    }

    var didCallValue: Bool = false
    var valueCalls: [String] = []
    func value(for key: String) throws -> Value? {
        didCallValue = true
        valueCalls.append(key)
        return storage[key]
    }

    var didCallUpdateValue: Bool = false
    var updateValueCalls: [(Value?, String)] = []
    func updateValue(_ value: Value?, for key: String) throws {
        didCallUpdateValue = true
        updateValueCalls.append((value, key))
        storage[key] = value
    }

    var didCallReset: Bool = false
    func reset() throws {
        didCallReset = true
        storage.removeAll()
    }
}

class KeyedStorageCacheTests: XCTestCase {

    func testUpdateValueSet() throws {
        let newValue: Int = 42
        let key1: String = "key1"
        let storage1: StorageInterfaceMock<Int> = .init()

        let sut: KeyedStorageCache<Int> = KeyedStorageCache { key in
            switch key {
            case key1:
                return StorageBox(storage1)
            default:
                XCTFail("Should never happen")
                return StorageBox(StorageInterfaceMock())
            }
        }

        try sut.updateValue(newValue, for: key1)

        XCTAssertTrue(storage1.didCallUpdateValue)
        XCTAssertEqual(storage1.updateValueCalls, [newValue])
        try XCTAssertEqual(sut.value(for: key1), newValue)
    }

    func testUpdateValueUpdate() throws {
        let newValue: Int = 42
        let key1: String = "key1"
        let storage1: StorageInterfaceMock<Int> = .init(newValue + 1)

        let sut: KeyedStorageCache<Int> = KeyedStorageCache { key in
            switch key {
            case key1:
                return StorageBox(storage1)
            default:
                XCTFail("Should never happen")
                return StorageBox(StorageInterfaceMock())
            }
        }

        try sut.updateValue(newValue, for: key1)

        XCTAssertTrue(storage1.didCallUpdateValue)
        XCTAssertEqual(storage1.updateValueCalls, [newValue])
        try XCTAssertEqual(sut.value(for: key1), newValue)
    }

    func testGetValueExists() throws {
        let newValue: Int = 42
        let key1: String = "key1"
        let storage1: StorageInterfaceMock<Int> = .init(newValue)

        let sut: KeyedStorageCache<Int> = KeyedStorageCache { key in
            switch key {
            case key1:
                return StorageBox(storage1)
            default:
                XCTFail("Should never happen")
                return StorageBox(StorageInterfaceMock())
            }
        }

        let fetchedValue = try sut.value(for: key1)

        XCTAssertTrue(storage1.didCallValue)
        XCTAssertEqual(fetchedValue, newValue)
    }

    func testGetValueEmpty() throws {
        let key1: String = "key1"
        let storage1: StorageInterfaceMock<Int> = .init()

        let sut: KeyedStorageCache<Int> = KeyedStorageCache { key in
            switch key {
            case key1:
                return StorageBox(storage1)
            default:
                XCTFail("Should never happen")
                return StorageBox(StorageInterfaceMock())
            }
        }

        let fetchedValue = try sut.value(for: key1)

        XCTAssertTrue(storage1.didCallValue)
        XCTAssertNil(fetchedValue)
    }

    func testReset() throws {
        let key1: String = "key1"
        let key2: String = "key2"
        let storage1: StorageInterfaceMock<Int> = .init()
        let storage2: StorageInterfaceMock<Int> = .init()

        let sut: KeyedStorageCache<Int> = KeyedStorageCache { key in
            switch key {
            case key1:
                return StorageBox(storage1)
            case key2:
                return StorageBox(storage2)
            default:
                XCTFail("Should never happen")
                return StorageBox(StorageInterfaceMock())
            }
        }

        // Register storages.
        _ = try sut.updateValue(42, for: key1)
        _ = try sut.updateValue(42, for: key2)

        try sut.reset()

        // Calls reset for all known keys.
        XCTAssertTrue(storage1.didCallReset)
        XCTAssertTrue(storage2.didCallReset)
    }
}
