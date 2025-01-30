//
//  DataStorageBoxTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/23/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class DataStorageInterfaceMock<Value: Decodable>: StorageInterfaceMock<Value>, DataStorageInterface {
    var underlyingData: Data?

    init(_ underlyingData: Data? = nil, value underlyingValue: Value? = nil) {
        self.underlyingData = underlyingData
        super.init(underlyingValue)
    }

    var didCallSetRawData: Bool = false
    var setRawDataCalls: [Data?] = []
    func setRawData(_ data: Data?) throws {
        didCallSetRawData = true
        setRawDataCalls.append(data)
        underlyingData = data
        underlyingValue = data.flatMap { try? JSONDecoder().decode(Value.self, from: $0) }
    }

    var didCallGetRawData: Bool = false
    func getRawData() throws -> Data? {
        didCallGetRawData = true
        return underlyingData
    }
}

class DataStorageBoxTests: XCTestCase {
    func testUpdateValue() throws {
        let storageMock: DataStorageInterfaceMock<Int> = .init()
        let newValue: Int = 42

        let sut = DataStorageBox(storageMock)

        try sut.updateValue(newValue)

        XCTAssertEqual(storageMock.underlyingValue, newValue)
        XCTAssertTrue(storageMock.didCallUpdateValue)
        XCTAssertEqual(storageMock.updateValueCalls, [42])
    }

    func testGetValue() throws {
        let value: Int = 42
        let storageMock: DataStorageInterfaceMock<Int> = .init(value: value)

        let sut = DataStorageBox(storageMock)

        try XCTAssertEqual(sut.value(), value)
        XCTAssertTrue(storageMock.didCallValue)
    }

    func testReset() throws {
        let value: Int = 42
        let storageMock: DataStorageInterfaceMock<Int> = .init(value: value)

        let sut = DataStorageBox(storageMock)
        XCTAssertNotNil(storageMock.underlyingValue)

        try sut.reset()

        XCTAssertNil(storageMock.underlyingValue)
        XCTAssertTrue(storageMock.didCallReset)
    }

    func testSetData() throws {
        let storageMock: DataStorageInterfaceMock<Int> = .init()
        let newData: Data = Data([42])

        let sut = DataStorageBox(storageMock)

        try sut.setRawData(newData)

        XCTAssertEqual(storageMock.underlyingData, newData)
        XCTAssertTrue(storageMock.didCallSetRawData)
        XCTAssertEqual(storageMock.setRawDataCalls, [newData])
    }

    func testGetData() throws {
        let data: Data = Data([42])
        let storageMock: DataStorageInterfaceMock<Int> = .init(data)

        let sut = DataStorageBox(storageMock)

        try XCTAssertEqual(sut.getRawData(), data)
        XCTAssertTrue(storageMock.didCallGetRawData)
    }
}
