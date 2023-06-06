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
    static let shared = Utils()

    /// Hashes a string to a float between 0 and 1
    ///
    /// fnv32a returns an integer, so we convert that to a float using a modulus
    func hash(data: String) -> Float {
        let hash = digest(data)
        let remainder = hash % 1000
        let value = Float(remainder) / 1000
        return value
    }

    /// This checks if a userId is within an experiment namespace or not.
    func inNamespace(userId: String, namespace: NameSpace) -> Bool {
        let hash = hash(data: userId + "__" + namespace.0)
        return hash >= namespace.1 && hash < namespace.2
    }

    /// Returns an array of floats with numVariations items that are all equal and sum to 1. For example, getEqualWeights(2) would return [0.5, 0.5].
    func getEqualWeights(numVariations: Int) -> [Float] {
        var weights: [Float] = []
        if numVariations >= 1 {
            let result = 1.0 / Float(numVariations)

            for _ in 0..<numVariations {
                weights.append(result)
            }
        }
        return weights
    }

    /// This converts and experiment's coverage and variation weights into an array of bucket ranges.
    func getBucketRanges(numVariations: Int, coverage: Float, weights: [Float]) -> [BucketRange] {
        var bucketRange: [BucketRange]

        var targetCoverage = coverage

        // Clamp the value of coverage to between 0 and 1 inclusive.
        if coverage < 0 { targetCoverage = 0 }
        if coverage > 1 { targetCoverage = 1 }

        // Default to equal weights if the weights don't match the number of variations.
        var targetWeights = weights
        if weights.count != numVariations {
            targetWeights = getEqualWeights(numVariations: numVariations)
        }

        // Default to equal weights if the sum is not equal 1 (or close enough when rounding errors are factored in):
        let weightsSum = targetWeights.sum()
        if weightsSum < 0.99 || weightsSum > 1.01 {
            targetWeights = getEqualWeights(numVariations: numVariations)
        }

        // Convert weights to ranges and return
        var cumulative: Float = 0

        bucketRange = targetWeights.map { weight in
            let start = cumulative
            cumulative += weight

            return BucketRange(start.roundTo(numFractionDigits: 4), (start + (targetCoverage * weight)).roundTo(numFractionDigits: 4))
        }

        return bucketRange
    }

    /// Choose Variation from List of ranges which matches particular number
    func chooseVariation(n: Float, ranges: [BucketRange]) -> Int {

        var counter = 0
        for range in ranges {
            if n >= range.0 && n < range.1 {
                return counter
            }
            counter += 1
        }

        return -1
    }

    /// Convert JsonArray to NameSpace
    func getGBNameSpace(namespace: [JSON]) -> NameSpace? {
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
    
    func paddedVersionString(input: String) -> String {
        var parts = input.replacingOccurrences(of: "[v]", with: "", options: .regularExpression)
        if let range = parts.range(of: "+")?.lowerBound {
            parts = String(parts.prefix(upTo: range))
        }
        
        var partArray = parts.components(separatedBy: [".", "-"])
        
        if partArray.count == 3 {
            partArray.append("~")
        }
        
        let paddedVersion = partArray.map({ $0.rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil ? "    " + $0 : $0}).joined(separator: "-")
                
        return paddedVersion
    }

    private func digest(_ string: String) -> UInt32 {
        return Common.fnv1a(Array(string.utf8), offsetBasis: Common.offsetBasis32, prime: Common.prime32)
    }
}
