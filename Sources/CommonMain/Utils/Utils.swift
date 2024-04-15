import Foundation


/// GrowthBook Utils Class
///
/// Contains Methods for:
/// - hash
/// - inNameSpace
/// - getEqualWeights
/// - getBucketRanges
/// - chooseVariation
/// - getGBNameSpace
public class Utils {
    
    /// Hashes a string to a float between 0 and 1
    ///
    static func hash(seed: String, value: String, version: Float) -> Float? {
        
        switch version {
        case 2:
            // New unbiased hashing algorithm
            let combinedValue = seed + value
            let hashedCombinedValue = digest(combinedValue).description + ""
            let hashedValue = digest(hashedCombinedValue) % 10000
            return Float(hashedValue) / 10000
        case 1:
            // Original biased hashing algorithm (keep for backwards compatibility)
            let combinedValue = value + seed
            let hashedValue = digest(combinedValue)
            return Float(hashedValue % 1000) / 1000
        default:
            // Unknown hash version
            return nil
        }
    }

    /// This checks if a userId is within an experiment namespace or not.
    static func inNamespace(userId: String, namespace: NameSpace) -> Bool {
        guard let hash = hash(seed: namespace.0, value: userId + "__", version: 1.0) else { return false }
        return inRange(n: hash, range: BucketRange(number1: namespace.1, number2: namespace.2))
    }

    /// Returns an array of floats with numVariations items that are all equal and sum to 1. For example, getEqualWeights(2) would return [0.5, 0.5].
    static func getEqualWeights(numVariations: Int) -> [Float] {
        if numVariations <= 0 { return [] }
        return Array(repeating: 1.0 / Float(numVariations), count: numVariations)
    }

    /// This converts and experiment's coverage and variation weights into an array of bucket ranges.
    static func getBucketRanges(numVariations: Int, coverage: Float, weights: [Float]?) -> [BucketRange] {
        var bucketRange: [BucketRange]

        var targetCoverage = coverage

        // Clamp the value of coverage to between 0 and 1 inclusive.
        if coverage < 0 { targetCoverage = 0 }
        if coverage > 1 { targetCoverage = 1 }

        // Default to equal weights if the weights don't match the number of variations.
        let equal = getEqualWeights(numVariations: numVariations)
        var targetWeights = weights ?? equal
        if targetWeights.count != numVariations {
            targetWeights = equal
        }

        // Default to equal weights if the sum is not equal 1 (or close enough when rounding errors are factored in):
        let weightsSum = targetWeights.sum()
        if weightsSum < 0.99 || weightsSum > 1.01 {
            targetWeights = equal
        }

        // Convert weights to ranges and return
        var cumulative: Float = 0

        bucketRange = targetWeights.map { weight in
            let start = cumulative
            cumulative += weight

            return BucketRange(number1: start.roundTo(numFractionDigits: 4), number2: (start + (targetCoverage * weight)).roundTo(numFractionDigits: 4))
        }

        return bucketRange
    }
    
    static func inRange(n: Float, range: BucketRange) -> Bool {
        return n >= range.number1 && n < range.number2
    }

    /// Choose Variation from List of ranges which matches particular number
    static func chooseVariation(n: Float, ranges: [BucketRange]) -> Int {
        for (index, range) in ranges.enumerated() {
            if inRange(n: n, range: range) {
                return index
            }
        }
        return -1
    }

    /// Convert JsonArray to NameSpace
    static func getGBNameSpace(namespace: [JSON]) -> NameSpace? {
        if namespace.count >= 3 {

            let title = namespace[0].string
            let start = namespace[1].float
            let end = namespace[2].float

            if let title = title, let start = start, let end = end {
                return NameSpace(title, start, end)
            }

        }
        return nil
    }

    static func paddedVersionString(input: String) -> String {
        var parts = input.replacingOccurrences(of: "[v]", with: "", options: .regularExpression)
        
        if let range = parts.range(of: "+")?.lowerBound {
            parts = String(parts.prefix(upTo: range))
        }
        
        var partArray = parts.components(separatedBy: [".", "-"])
        
        if partArray.count == 3 {
            partArray.append("~")
        }
        
        return partArray.map({ $0.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil ? String(repeating: " ", count: 5 - $0.count) + $0 : $0}).joined(separator: "-")
    }
    
    static func convertJsonToDouble(from value: JSON?) -> Double? {
        if let doubleValue = value?.double {
            return doubleValue
        } else if let stringValue = value?.string {
            let doubleFromString = Double(stringValue)
            return doubleFromString
        }
        return nil
    }

    static private func digest(_ string: String) -> UInt32 {
        return Common.fnv1a(Array(string.utf8), offsetBasis: Common.offsetBasis32, prime: Common.prime32)
    }
    
    ///Returns tuple out of 2 elements: the attribute itself an its hash value
    static func getHashAttribute(context: Context, attr: String?, fallback: String? = nil, attributeOverrides: JSON) -> (hashAttribute: String, hashValue: String) {
        var hashAttribute = attr ?? "id"
        var hashValue = ""
        
        if attributeOverrides[hashAttribute] != .null {
            hashValue = attributeOverrides[hashAttribute].stringValue
        } else if context.attributes[hashAttribute] != .null {
            hashValue = context.attributes[hashAttribute].stringValue
        }
        
        // if no match, try fallback
        if hashValue.isEmpty, let fallback = fallback {
            if attributeOverrides[fallback] != .null {
                hashValue = attributeOverrides[fallback].stringValue
            } else if context.attributes[fallback] != .null {
                hashValue = context.attributes[fallback].stringValue
            }
            
            if !hashValue.isEmpty {
                hashAttribute = fallback
            }
        }
        
        return (hashAttribute, hashValue)
    }
}
