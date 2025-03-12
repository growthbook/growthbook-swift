//
//  KeyedStorage.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// Multi-key interface for storing values.
public protocol KeyedStorageInterface: AnyObject, Sendable {
    /// Associated value type.
    associatedtype Value

    /// Returns stored value for a given key.
    /// - Parameter key: A key to return value for.
    func value(for key: String) throws -> Value?

    /// Stores a new value for a given key.
    /// - Parameters:
    ///   - value: A new value to store.
    ///   - key: A key to sat value for.
    func updateValue(_ value: Value?, for key: String) throws
    
    /// Reset storage.
    func reset() throws
}

final class KeyedStorageBox<Value>: Sendable {
    private let storage: any KeyedStorageInterface
    private let getValueClosure: @Sendable (_ key: String) throws -> Value?
    private let updateValueClosure: @Sendable (_ value: Value?, _ key: String) throws -> Void

    init<Storage: KeyedStorageInterface>(_ storage: Storage) where Storage.Value == Value {
        self.storage = storage
        self.getValueClosure = { try storage.value(for: $0) }
        self.updateValueClosure = { try storage.updateValue($0, for: $1) }
    }
}

extension KeyedStorageBox: KeyedStorageInterface {
    func value(for key: String) throws -> Value? {
        try getValueClosure(key)
    }
    
    func updateValue(_ value: Value?, for key: String) throws {
        try updateValueClosure(value, key)
    }
    
    func reset() throws {
        try storage.reset()
    }
}

/// File storage for codable values.
final class KeyedStorageCache<Value: Codable> {
    /// Stored value.
    ///
    /// Storing a copy in memory to reduce file read and decoding operations.
    ///
    /// The value is not read until first access. This allows to handle load and parse errors on first access.
    private let storedValue: Protected<[String: StorageBox<Value>]> = .init([:])

    private let storageBoxBuilder: @Sendable (_ key: String) -> StorageBox<Value>

    init(storageBoxBuilder: @escaping @Sendable (_ key: String) -> StorageBox<Value>) {
        self.storageBoxBuilder = storageBoxBuilder
    }

    convenience init<Storage: StorageInterface>(
        storageBuilder: @escaping @Sendable (_ key: String) -> Storage
    ) where Storage.Value == Value {
        self.init(storageBoxBuilder: { .init(storageBuilder($0)) })
    }
}

extension KeyedStorageCache: KeyedStorageInterface {
    func _storageBox(for key: String, from storedValue: inout [String: StorageBox<Value>]) -> StorageBox<Value> {
        let storageBox: StorageBox<Value>

        if let existingStorageBox = storedValue[key] {
            storageBox = existingStorageBox
        } else {
            let box = storageBoxBuilder(key)
            storedValue[key] = box
            storageBox = box
        }
        return storageBox
    }

    func value(for key: String) throws -> Value? {
        try storedValue.write { try _storageBox(for: key, from: &$0).value() }
    }

    func updateValue(_ value: Value?, for key: String) throws {
        try storedValue.write { try _storageBox(for: key, from: &$0).updateValue(value) }
    }

    func reset() throws {
        try storedValue.write { storedValue in
            try storedValue.values.forEach { try $0.reset() }
            storedValue.removeAll()
        }
    }
}
