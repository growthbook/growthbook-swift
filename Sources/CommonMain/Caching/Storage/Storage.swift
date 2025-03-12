//
//  StorageInterface.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// Interface for storing values.
public protocol StorageInterface: AnyObject, Sendable {
    /// Associated value type.
    associatedtype Value

    /// Returns stored value.
    func value() throws -> Value?

    /// Stores a new value.
    /// - Parameter value: A new value to store.
    func updateValue(_ value: Value?) throws

    /// Reset storage.
    func reset() throws
}

final class StorageBox<Value> {
    private let storage: any StorageInterface
    private let updateValueClosure: @Sendable (_ value: Value?) throws -> Void

    init<Storage: StorageInterface>(_ storage: Storage) where Storage.Value == Value {
        self.storage = storage
        self.updateValueClosure = { try storage.updateValue($0) }
    }
}

extension StorageBox: StorageInterface {
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
