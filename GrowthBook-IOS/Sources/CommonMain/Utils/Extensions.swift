import Foundation
import SwiftyJSON

extension Float {
    func roundTo(numFractionDigits: Int) -> Float {
        let factor = pow(10.0, Float(numFractionDigits))
        return roundf(self * factor) / factor
    }
}

extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element { reduce(.zero, +) }
}

extension JSON {
    static func convertToArrayFloat(jsonArray: [JSON]) -> [Float] {
        var floats: [Float] = []
        jsonArray.forEach { json in
            floats.append(json.floatValue)
        }
        return floats
    }

    static func convertToArrayString(jsonArray: [JSON]) -> [String] {
        var array: [String] = []
        jsonArray.forEach { json in
            array.append(json.stringValue)
        }
        return array
    }

    static func convertToTwoArrayFloat(jsonArray: [JSON]) -> [[Float]] {
        var array: [[Float]] = []
        jsonArray.forEach { json in
            var values: [Float] = []
            json.arrayValue.forEach { item in
                values.append(item.floatValue)
            }
            array.append(values)
        }
        return array
    }
}

/// String extension to convert to NSData
extension String {
    func toData() -> Data? {
        return (self as NSString).data(using: String.Encoding.utf8.rawValue)
    }
}

/// NSData extension to convert to String
extension Data {
    func string() -> String? {
        return NSString(data: self, encoding: String.Encoding.utf8.rawValue) as String?
    }
}
