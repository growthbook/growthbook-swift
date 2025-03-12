//
//  DataStorage.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// Interface for storing values that can be represented as `Data`.
protocol DataStorageInterface: StorageInterface {
    /// Stores a new encoded value.
    /// - Parameter data: A new encoded value.
    func setRawData(_ data: Data?) throws

    /// Returns an encoded value.
    func getRawData() throws -> Data?
}


final class DataStorageBox<Value>: Sendable {
    private let storage: any DataStorageInterface
    private let updateValueClosure: @Sendable (_ value: Value?) throws -> Void

    init<Storage: DataStorageInterface>(_ storage: Storage) where Storage.Value == Value {
        self.storage = storage
        self.updateValueClosure = { try storage.updateValue($0) }
    }
}

extension DataStorageBox: StorageInterface {
    func value() throws -> Value? {
        try storage.value() as! Value?
    }

    func updateValue(_ value: Value?) throws {
        try updateValueClosure(value)
    }

    func reset() throws {
        try storage.reset()
    }
}

extension DataStorageBox: DataStorageInterface {
    func getRawData() throws -> Data? {
        try storage.getRawData()
    }

    func setRawData(_ data: Data?) throws {
        try storage.setRawData(data)
    }
}
