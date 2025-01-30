//
//  StorageBoxTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/23/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class StorageInterfaceMock<Value>: StorageInterface {
    var underlyingValue: Value?
    init(_ underlyingValue: Value? = nil) {
        self.underlyingValue = underlyingValue
    }

    var didCallValue: Bool = false
    func value() throws -> Value? {
        didCallValue = true
        return underlyingValue
    }

    var didCallUpdateValue: Bool = false
    var updateValueCalls: [Value?] = []
    func updateValue(_ value: Value?) throws {
        underlyingValue = value
        didCallUpdateValue = true
        updateValueCalls.append(value)
    }

    var didCallReset: Bool = false
    func reset() throws {
        didCallReset = true
        underlyingValue = .none
    }
}

class StorageBoxTests: XCTestCase {
    func testUpdateValue() throws {
        let storageMock: StorageInterfaceMock<Int> = .init()
        let newValue: Int = 42

        let sut = StorageBox(storageMock)

        try sut.updateValue(newValue)

        XCTAssertEqual(storageMock.underlyingValue, newValue)
        XCTAssertTrue(storageMock.didCallUpdateValue)
        XCTAssertEqual(storageMock.updateValueCalls, [42])
    }

    func testGetValue() throws {
        let value: Int = 42
        let storageMock: StorageInterfaceMock<Int> = .init(value)

        let sut = StorageBox(storageMock)

        try XCTAssertEqual(sut.value(), value)
        XCTAssertTrue(storageMock.didCallValue)
    }

    func testReset() throws {
        let value: Int = 42
        let storageMock: StorageInterfaceMock<Int> = .init(value)

        let sut = StorageBox(storageMock)
        XCTAssertNotNil(storageMock.underlyingValue)

        try sut.reset()

        XCTAssertNil(storageMock.underlyingValue)
        XCTAssertTrue(storageMock.didCallReset)
    }
}
