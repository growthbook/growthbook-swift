//
//  Protected.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/21/25.
//

import Foundation

/// Synchronous thread-safe read/write accessor to the wrapped value.
final class Protected<Value> {
    #if compiler(>=6)
    private nonisolated(unsafe) var value: Value
    #else
    private var value: Value
    #endif

    private let lock: NSLock = .init()

    init(_ value: Value) {
        self.value = value
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read() -> Value {
        read { value in value }
    }

    /// Synchronously read or transform the contained value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The return value of the closure passed.
    func read<U>(_ closure: (Value) throws -> U) rethrows -> U {
        try lock.read { try closure(self.value) }
    }

    /// Synchronously modify the protected value.
    ///
    /// - Parameter closure: The closure to execute.
    ///
    /// - Returns:           The modified value.
    @discardableResult
    func write<U>(_ closure: (inout Value) throws -> U) rethrows -> U {
        try lock.write { try closure(&self.value) }
    }

    /// Synchronously update the protected value.
    ///
    /// - Parameter value: The `Value`.
    func write(_ value: Value) {
        write { $0 = value }
    }
}

#if compiler(>=6)
extension Protected: Sendable {}
#else
extension Protected: @unchecked Sendable {}
#endif

private extension NSLocking {
    func read<R>(_ closure: () throws -> R) rethrows -> R {
        try withLock { try closure() }
    }

    func write<R>(_ closure: () throws -> R) rethrows -> R {
        try withLock { try closure() }
    }
}
