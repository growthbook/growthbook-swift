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
            func caseFold(_ value: JSON) -> String? {
                return value.string?.lowercased()
            }

            // actual is JSON array ["d", "a"]
            if let actualArray = (actual as? JSON)?.arrayValue, !actualArray.isEmpty {
                return actualArray.contains { actualItem in
                    expectedJSON.contains { expectedItem in
                        guard let a = caseFold(actualItem), let e = caseFold(expectedItem) else {
                            return actualItem == expectedItem
                        }
                        return a == e
                    }
                }
            }
            // actual is JSON string "a"
            if let actualJSON = actual as? JSON, let actualStr = actualJSON.string?.lowercased() {
                return expectedJSON.contains { caseFold($0) == actualStr }
            }

            // actual is  String
            if let actualStr = (actual as? String)?.lowercased() {
                return expectedJSON.contains { caseFold($0) == actualStr }
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
