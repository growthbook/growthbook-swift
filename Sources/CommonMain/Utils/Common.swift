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

}
