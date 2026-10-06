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

    static func isIn<T: Equatable>(actual: Any, expected: [T], insensitive: Bool = false) -> Bool {
        
        if insensitive, let expectedJSON = expected as? [JSON] {
            // Case folding only applies to strings. Anything else — a number, a bool, null — is
            // compared as-is, so the insensitive operators agree with their sensitive counterparts
            // on every value that has no case to ignore. Comparing only the folded forms would make
            // those values match nothing, which flips $nini to "not in the list" for a value that
            // is plainly in it.
            func matches(_ actualItem: JSON, _ expectedItem: JSON) -> Bool {
                guard let a = actualItem.string?.lowercased(),
                      let e = expectedItem.string?.lowercased() else {
                    return actualItem == expectedItem
                }
                return a == e
            }

            if let actualJSON = actual as? JSON {
                // actual is a JSON array ["d", "a"] — any overlap counts
                if let actualArray = actualJSON.array, !actualArray.isEmpty {
                    return actualArray.contains { actualItem in
                        expectedJSON.contains { matches(actualItem, $0) }
                    }
                }
                // actual is a scalar: a string, but also a number, a bool or null
                return expectedJSON.contains { matches(actualJSON, $0) }
            }

            // actual is a bare String
            if let actualStr = actual as? String {
                return expectedJSON.contains { matches(JSON(actualStr), $0) }
            }

            return false
        }
            
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
    
    static func isInAll(
        actual: JSON,
        expected: [JSON],
        savedGroups: JSON?,
        insensitive: Bool,
        evalCondtitionValue: (JSON, JSON, JSON?) -> Bool
    ) -> Bool {
        guard let actualArray = actual.array else { return false }
        
        for expectedItem in expected {
            let passed = actualArray.contains { actualItem in
                evalCondtitionValue(expectedItem, actualItem, savedGroups)
            }
            if !passed { return false}
            
        }
        return true
    }

}
