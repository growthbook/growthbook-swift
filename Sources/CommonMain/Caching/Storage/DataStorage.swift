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

class DataStorageBox<Value>: StorageBox<Value> {
    private let storage: any DataStorageInterface

    init<Storage: DataStorageInterface>(_ storage: Storage) where Storage.Value == Value {
        self.storage = storage
        super.init(storage)
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
