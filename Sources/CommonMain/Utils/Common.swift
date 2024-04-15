import Foundation

final class Common {
    // MARK: - Enum, Const
    static let offsetBasis32: UInt32 = 2166136261
    static let offsetBasis64: UInt64 = 14695981039346656037
    static let prime32: UInt32 = 16777619
    static let prime64: UInt64 = 1099511628211

}

// MARK: - Algorithm
extension Common {
    static func fnv1<T: FixedWidthInteger>(_ array: [UInt8], offsetBasis: T, prime: T) -> T {
        var hash: T = offsetBasis

        for elm in array {
            hash = hash &* prime
            hash = hash ^ T(elm)
        }

        return hash
    }

    static func fnv1a<T: FixedWidthInteger>(_ array: [UInt8], offsetBasis: T, prime: T) -> T {
        var hash: T = offsetBasis

        for elm in array {
            hash = hash ^ T(elm)
            hash = hash &* prime
        }

        return hash
    }
    
    static func isEqual<T>(_ a: T, _ b: T) -> Bool where T : Equatable {
        return a == b
    }

    static func isIn<T: Equatable>(actual: Any, expected: [T]) -> Bool {
        // Check if actual is an array
        if let actualArray = actual as? [T] {
            return actualArray.contains { expected.contains($0) }
        } else if let actualArray = (actual as? JSON)?.arrayValue, !actualArray.isEmpty, let expectedArray = expected as? [JSON] {
            return actualArray.contains { expectedArray.contains($0) }
        }
        
        if let actualValue = actual as? T {
            return expected.contains(actualValue)
        }
        return false
    }

}
