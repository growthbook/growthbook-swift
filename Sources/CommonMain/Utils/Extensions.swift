import Foundation

extension Sequence where Element: AdditiveArithmetic {
    func sum() -> Element { reduce(.zero, +) }
}

extension JSON {
    static func convertToArrayDouble(jsonArray: [JSON]) -> [Double] {
        var doubles: [Double] = []
        jsonArray.forEach { json in
            doubles.append(json.doubleValue)
        }
        return doubles
    }

    static func convertToArrayString(jsonArray: [JSON]) -> [String] {
        var array: [String] = []
        jsonArray.forEach { json in
            array.append(json.stringValue)
        }
        return array
    }

    static func convertToTwoArrayDouble(jsonArray: [JSON]) -> [[Double]] {
        var array: [[Double]] = []
        jsonArray.forEach { json in
            var values: [Double] = []
            json.arrayValue.forEach { item in
                values.append(item.doubleValue)
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

extension String {
    /// The last path component of the receiver.
    var lastPathComponent: String {
        return NSString(string: self).lastPathComponent
    }

    /// A new string made by deleting the extension from the receiver.
    var stringByDeletingPathExtension: String {
        return NSString(string: self).deletingPathExtension
    }

    /**
     Returns a string colored with the specified color.

     - parameter color: The string representation of the color.

     - returns: A string colored with the specified color.
     */
    func withColor(_ color: String?) -> String {
        guard let color = color else {
            return self
        }

        return "\u{001b}[fg\(color);\(self)\u{001b}[;"
    }
}
