import Foundation

/// Both experiments and features can define targeting conditions using a syntax modeled after MongoDB queries.
///
/// These conditions can have arbitrary nesting levels and evaluating them requires recursion.
/// There are a handful of functions to define, and be aware that some of them may reference function definitions further below.

/// Enum For different Attribute Types supported by GrowthBook
enum AttributeType: String {
    /// String Type Attribute
    case gbString = "string"
    /// Number Type Attribute
    case gbNumber = "number"
    /// Bool Type Attribute
    case gbBool = "boolean"
    /// Array Type Attribute
    case gbArray = "array"
    /// Object Type Attribute
    case gbObject = "object"
    /// Null Type Attribute
    case gbNil = "null"
    /// Not Supported Type Attribute
    case gbUnknown = "unknown"
}

func getAttributeType(index: Int) -> String {
    switch index {
    case 0:
        return AttributeType.gbNumber.rawValue
    case 1:
        return AttributeType.gbString.rawValue
    case 2:
        return AttributeType.gbBool.rawValue
    case 3:
        return AttributeType.gbArray.rawValue
    case 4:
        return AttributeType.gbObject.rawValue
    case 5:
        return AttributeType.gbNil.rawValue
    case 6:
        return AttributeType.gbUnknown.rawValue
    default:
        return AttributeType.gbUnknown.rawValue
    }
}

/// Evaluator Class for Conditions
class ConditionEvaluator {
    /// This is the main function used to evaluate a condition. It loops through the condition key/value pairs and checks each entry:
    /// - attributes : User Attributes
    /// - condition : to be evaluated
    func isEvalCondition(attributes: JSON, conditionObj: JSON, savedGroups: JSON? = nil) -> Bool {
        if !conditionObj.arrayValue.isEmpty {
            return false
        }
        // Condition is an object, keys are either specific operators or object paths values are either arguments for operators or conditions for paths
        for (key, value) in conditionObj.dictionaryValue {
            switch key {
            case "$or":
                guard isEvalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups) else { return false }
            case "$nor":
                guard !isEvalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups) else { return false }
            case "$and":
                guard isEvalAnd(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups) else { return false }
            case "$not":
                guard !isEvalCondition(attributes: attributes, conditionObj: value, savedGroups: savedGroups) else { return false }
            default:
                let element = getPath(obj: attributes, key: key)
                guard isEvalConditionValue(conditionValue: value, attributeValue: element, savedGroups: savedGroups) else { return false }
            }
        }
        // If none of the entries failed their checks, `evalCondition` returns true
        return true
    }

    /// Evaluate OR conditions against given attributes
    func isEvalOr(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool {
        // If conditionObjs is empty, return true
        guard conditionObjs.isEmpty == false else {
            return true
        }
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is true, break out of the loop and return true
            if isEvalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups) {
                return true
            }
        }

        // Return false
        return false
    }

    /// Evaluate AND conditions against given attributes
    func isEvalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool {
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is false, break out of the loop and return false
            if !isEvalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups) {
                return false
            }
        }
        // Return true
        return true
    }

    /// This accepts a parsed JSON object as input and returns true if every key in the object starts with $
    func isOperatorObject(obj: JSON) -> Bool {
        var isOperator = true
        if let value = obj.dictionary, !value.keys.isEmpty {
            for key in value.keys {
                if key.first != "$" {
                    isOperator = false
                    break
                }
            }
        } else {
            isOperator = false
        }
        return isOperator
    }

    /// This returns the data type of the passed in argument.
    func getType(obj: JSON?) -> String {
        guard let value = obj else { return AttributeType.gbUnknown.rawValue }
        return getAttributeType(index: value.type.rawValue)
    }

    /// Given attributes and a dot-separated path string, return the value at that path (or null/undefined if the path doesn't exist)
    func getPath(obj: JSON, key: String) -> JSON? {
        var paths: [String]

        if key.contains(".") {
            paths = key.components(separatedBy: ".")  //split(".") as [String]
        } else {
            paths = []
            paths.append(key)
        }

        var element = obj

        for path in paths {
            if let _ = element.array {
                return nil
            }
            if let dict = element.dictionary, let value = dict[path] {
                element = value
            } else {
                return nil
            }
        }
        return element
    }

    /// Evaluates Condition Value against given condition & attributes
    func isEvalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil, insensitive: Bool = false) -> Bool {
        // Plain values compare the way the JS SDK does: a string condition against the attribute
        // converted to a string, a number condition against the attribute coerced to a number, a
        // boolean condition against the attribute's truthiness, and arrays by their JSON encoding.
        // A missing attribute is null here, as `getPath` returns null for a missing path in JS.
        let unwrappedAttribute = attributeValue ?? .null

        if let condStr = conditionValue.string {
            let attrStr = JSCoercion.string(unwrappedAttribute)
            return insensitive ? attrStr.lowercased() == condStr.lowercased() : attrStr == condStr
        }

        if conditionValue.type == .number {
            return JSCoercion.number(unwrappedAttribute) == conditionValue.doubleValue
        }

        if conditionValue.type == .bool {
            return unwrappedAttribute.type != .null && JSCoercion.isTruthy(unwrappedAttribute) == conditionValue.boolValue
        }

        if conditionValue.type == .null {
            return unwrappedAttribute.type == .null
        }

        if conditionValue.array != nil {
            return JSCoercion.isJSONEqual(conditionValue, unwrappedAttribute)
        }

        // Processing condition objects
        if let _ = conditionValue.dictionary {
            if isOperatorObject(obj: conditionValue) {
                for key in conditionValue.dictionaryValue.keys {
                    if let value = conditionValue.dictionaryValue[key],
                       !isEvalOperatorCondition(operatorKey: key,
                                               attributeValue: unwrappedAttribute,
                                               conditionValue: value,
                                               savedGroups: savedGroups) {
                        return false
                    }
                }
                return true
            }
            return JSCoercion.isJSONEqual(conditionValue, unwrappedAttribute)
        }

        return false
    }

    /// This checks if attributeValue is an array, and if so at least one of the array items must match the condition
    func isElemMatch(attributeValue: [JSON], condition: JSON, savedGroups: JSON?) -> Bool {

        // Loop through items in attributeValue
        for item in attributeValue {
            // If isOperatorObject(condition)
            if isOperatorObject(obj: condition) {
                // If evalConditionValue(condition, item), break out of loop and return true
                if isEvalConditionValue(conditionValue: condition, attributeValue: item, savedGroups: savedGroups) {
                    return true
                }
            }
            // Else if evalCondition(item, condition), break out of loop and return true
            else if isEvalCondition(attributes: item, conditionObj: condition, savedGroups: savedGroups) {
                return true
            }
        }

        // If attributeValue is not an array, return false
        return false
    }

    /// This function is just a case statement that handles all the possible operators
    ///
    /// There are basic comparison operators in the form attributeValue {op} conditionValue
    func isEvalOperatorCondition(operatorKey: String, attributeValue: JSON, conditionValue: JSON, savedGroups: JSON? = nil) -> Bool {
        let conditionJson = JSON(conditionValue)
        // Evaluate TYPE operator - whether both are of same type
        if operatorKey == "$type" {
            return getType(obj: attributeValue) == conditionJson.stringValue
        }

        // Evaluate NOT operator - whether condition doesn't contain attribute
        if operatorKey == "$not" {
            return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups)
        }

        // Evaluate EXISTS operator - whether condition contains attribute
        if operatorKey == "$exists" {
            let targetPrimitiveValue = conditionJson.stringValue
            if targetPrimitiveValue == "false" && attributeValue == .null {
                return true
            } else if targetPrimitiveValue == "true" && attributeValue != .null {
                return true
            }
        }

        switch operatorKey {
        case "$type":
            return  getType(obj: attributeValue) == conditionJson.stringValue
        case "$not":
            if let conditionValue = conditionValue.dictionaryValue.values.first {
                return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups)
            }
        case "$exists":
            let targetPrimitiveValue = conditionJson.stringValue
            if targetPrimitiveValue == "false" && attributeValue == .null {
                return true
            } else if targetPrimitiveValue == "true" && attributeValue != .null {
                return true
            }
        default: break
        }

        // The saved-group operators resolve the group themselves and work for any attribute shape —
        // scalar, array or absent — so they are handled before the dispatch below, which branches on
        // the shape of the attribute and would otherwise leave them unreachable for array attributes.
        //
        // Both always return: an absent attribute simply makes the user a non-member, so $inGroup is
        // false and $notInGroup is true. Returning only from inside a non-null guard would drop out
        // of the switch and yield false for both, breaking the negation.
        switch operatorKey {
        case "$inGroup":
            return Common.isIn(actual: attributeValue, expected: resolveSavedGroup(conditionValue, savedGroups))
        case "$notInGroup":
            return !Common.isIn(actual: attributeValue, expected: resolveSavedGroup(conditionValue, savedGroups))
        default: break
        }

        // The version operators coerce their operands themselves (numbers become strings, everything
        // else becomes "0"), so they are handled before the dispatch below, which branches on the
        // shape of the attribute and would otherwise leave them unreachable for array or absent
        // attributes and skip them whenever the condition value is not a string.
        switch operatorKey {
        case "$veq":
            return Utils.paddedVersionString(input: attributeValue) == Utils.paddedVersionString(input: conditionValue)
        case "$vne":
            return Utils.paddedVersionString(input: attributeValue) != Utils.paddedVersionString(input: conditionValue)
        case "$vgt":
            return Utils.paddedVersionString(input: attributeValue) > Utils.paddedVersionString(input: conditionValue)
        case "$vgte":
            return Utils.paddedVersionString(input: attributeValue) >= Utils.paddedVersionString(input: conditionValue)
        case "$vlt":
            return Utils.paddedVersionString(input: attributeValue) < Utils.paddedVersionString(input: conditionValue)
        case "$vlte":
            return Utils.paddedVersionString(input: attributeValue) <= Utils.paddedVersionString(input: conditionValue)
        default: break
        }

        // The membership operators are decided before the non-null gate below, because they must
        // stay a true logical negation for an attribute the user does not have. `Common.isIn`
        // already reports a null attribute as "not a member", so $in is false and $nin is true on
        // their own merits. Returning only from inside the gate dropped out of the switch and
        // yielded false for both, so a rule written as an exclusion silently matched nobody —
        // the same defect #178 fixed for $inGroup / $notInGroup.
        if let conditionValue = conditionJson.array {
            switch operatorKey {
            case "$in":
                return Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$ini":
                return Common.isIn(actual: attributeValue, expected: conditionValue, insensitive: true)
            case "$nin":
                return !Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$nini":
                return !Common.isIn(actual: attributeValue, expected: conditionValue, insensitive: true)
            default: break
            }
        }

        /// The remaining array operators keep the non-null gate: $all over an attribute the user
        /// does not have is false, which matches the other SDKs.
        if let conditionValue = conditionJson.array, attributeValue != .null {
            switch operatorKey {
            case "$all":
                return Common.isInAll(
                        actual: attributeValue,
                        expected: conditionValue,
                        savedGroups: savedGroups,
                        insensitive: true
                    ) { con, attr, groups in
                        isEvalConditionValue(conditionValue: con, attributeValue: attr, savedGroups: groups, insensitive: false)
                    }
            case "$alli":
                return Common.isInAll(
                        actual: attributeValue,
                        expected: conditionValue,
                        savedGroups: savedGroups,
                        insensitive: true
                    ) { con, attr, groups in
                        isEvalConditionValue(conditionValue: con, attributeValue: attr, savedGroups: groups, insensitive: true)
                    }
            default: break
            }
        } else if let attribute = attributeValue.array {
            switch operatorKey {
            // Evaluate ELEMMATCH operator - whether condition matches attribute
            case "$elemMatch":
                return  isElemMatch(attributeValue: attribute, condition: conditionValue, savedGroups: savedGroups)
            // Evaluate SIE operator - whether condition size is same as that of attribute
            case "$size":
                return isEvalConditionValue(conditionValue: conditionValue, attributeValue: JSON(attribute.count), savedGroups: savedGroups)
            default: break
            }
        } else {
            switch operatorKey {
            // Evaluate EQ operator - whether condition equals to attribute
            case "$eq":
                return  attributeValue == conditionValue
            // Evaluate NE operator - whether condition doesn't equal to attribute
            case "$ne":
                return  attributeValue != conditionValue
            // Evaluate LT operator - whether attribute less than to condition
            case "$lt":
                if attributeValue == .null {
                    if let cond = conditionValue.double {
                        return 0.0 < cond
                    } else if let condStr = conditionValue.string, let cond = Double(condStr) {
                        return 0.0 < cond
                    }
                    return false
                }

                var attrNum: Double? = attributeValue.double
                if attrNum == nil, let str = attributeValue.string, let num = Double(str) {
                    attrNum = num
                }

                var condNum: Double? = conditionValue.double
                if condNum == nil, let condStr = conditionValue.string, let num = Double(condStr) {
                    condNum = num
                }

                if let attrNum, let condNum {
                    return attrNum < condNum
                }

                if let str = attributeValue.string, let cond = conditionValue.string {
                    return str < cond
                }

                return false

            // Evaluate LTE operator - whether attribute less than or equal to condition
            case "$lte":
                if attributeValue == .null {
                        if let cond = conditionValue.double {
                            return 0.0 <= cond
                        } else if let condStr = conditionValue.string, let cond = Double(condStr) {
                            return 0.0 <= cond
                        }
                        return false
                    }
                var attrNum: Double? = attributeValue.double
                if attrNum == nil, let str = attributeValue.string, let num = Double(str) {
                    attrNum = num
                }

                var condNum: Double? = conditionValue.double
                if condNum == nil, let condStr = conditionValue.string, let num = Double(condStr) {
                    condNum = num
                }

                if let attrNum, let condNum {
                    return attrNum <= condNum
                }
                    if let str = attributeValue.string, let cond = conditionValue.string {
                        return str <= cond
                    }
                    return false
            // Evaluate GT operator - whether attribute greater than to condition
            case "$gt":
                if attributeValue == .null {
                        if let cond = conditionValue.double {
                            return 0.0 > cond
                        } else if let condStr = conditionValue.string, let cond = Double(condStr) {
                            return 0.0 > cond
                        }
                        return false
                    }
                var attrNum: Double? = attributeValue.double
                if attrNum == nil, let str = attributeValue.string, let num = Double(str) {
                    attrNum = num
                }

                var condNum: Double? = conditionValue.double
                if condNum == nil, let condStr = conditionValue.string, let num = Double(condStr) {
                    condNum = num
                }

                if let attrNum, let condNum {
                    return attrNum > condNum
                }
                    if let str = attributeValue.string {
                        return str > conditionValue.stringValue
                    }
                    return false
            // Evaluate GTE operator - whether attribute greater than or equal to condition
            case "$gte":
                if attributeValue == .null {
                        if let cond = conditionValue.double {
                            return 0.0 >= cond
                        } else if let condStr = conditionValue.string, let cond = Double(condStr) {
                            return 0.0 >= cond
                        }
                        return false
                    }
                    if let num = attributeValue.double {
                        if let cond = conditionValue.double {
                                    return num >= cond
                                } else if let condStr = conditionValue.string, let condNum = Double(condStr) {
                                    return num >= condNum
                                }
                                return false
                    }
                    if let str = attributeValue.string, let cond = conditionValue.double, let num = Double(str) {
                        return num >= cond
                    }
                    if let str = attributeValue.string, let cond = conditionValue.string {
                        return str >= cond
                    }
                    return false
            // Evaluate REGEX operator - whether attribute contains condition regex
            case "$regex":
                return isContains(
                    source: attributeValue.stringValue,
                    target: conditionValue.stringValue,
                    insensitive: false,
                    negate: false
                )
            case "$regexi":
                return isContains(
                    source: attributeValue.stringValue,
                    target: conditionValue.stringValue,
                    insensitive: true,
                    negate: false
                )
            case "$notRegex":
                return isContains(
                    source: attributeValue.stringValue,
                    target: conditionValue.stringValue,
                    insensitive: false,
                    negate: true
                )
            case "$notRegexi":
                return isContains(
                    source: attributeValue.stringValue,
                    target: conditionValue.stringValue,
                    insensitive: true,
                    negate: true
                )
            default: break
            }
        }
        return false
    }

    private func isContains(source: String, target: String, insensitive: Bool, negate: Bool) -> Bool {
        let convertedItem = target.replacingOccurrences(of: "([^\\\\])\\/", with: "$1\\/")
        
        do {
            var options: NSRegularExpression.Options = []
            if insensitive {
                        options.insert(.caseInsensitive)
                    }
            let regex = try NSRegularExpression(pattern: convertedItem, options: options)
            let range = NSRange(location: 0, length: source.utf16.count)
            let isMatch = regex.firstMatch(in: source, options: [], range: range) != nil
            
            return negate ? !isMatch : isMatch
        } catch {
            return false
        }
    }

    /// Resolves the members of a saved group for the `$inGroup` / `$notInGroup` operators.
    ///
    /// An unknown group id, a missing `savedGroups` object, a non-array group value, or a group id
    /// that is not a string all resolve to an empty group — so membership is simply false and the
    /// negation stays meaningful.
    private func resolveSavedGroup(_ conditionValue: JSON, _ savedGroups: JSON?) -> [JSON] {
        guard let groupId = conditionValue.string else { return [] }
        return savedGroups?[groupId].array ?? []
    }

    private func isPrimitive(value: JSON) -> Bool {
        
        if value.number != nil || value.string != nil || value.bool != nil || value.int != nil || value == .null {
            return true
        }
        return false
    }
    
}

/// The JavaScript coercions the JS SDK relies on for plain-value conditions, so a condition
/// matches the same users here as it does there.
enum JSCoercion {
    /// `String(value)` in JS: `10`, `1.5`, `1e+21`, `"true"`, `"null"`, `"a,b"`, `"[object Object]"`.
    static func string(_ value: JSON) -> String {
        switch value.type {
        case .string:
            return value.stringValue
        case .number:
            return numberString(value.doubleValue)
        case .bool:
            return value.boolValue ? "true" : "false"
        case .array:
            return value.arrayValue.map { $0.type == .null ? "" : string($0) }.joined(separator: ",")
        case .dictionary:
            return "[object Object]"
        default:
            return "null"
        }
    }

    /// `Number(value)` in JS: numeric strings parse, `""` is 0, booleans are 1 / 0, null is 0, and
    /// anything else is NaN (which equals nothing).
    static func number(_ value: JSON) -> Double {
        switch value.type {
        case .number:
            return value.doubleValue
        case .bool:
            return value.boolValue ? 1 : 0
        case .string:
            return number(value.stringValue)
        case .array:
            return number(string(value))
        case .dictionary:
            return .nan
        default:
            return 0
        }
    }

    /// JS truthiness: `0`, `NaN`, `""`, `false` and null are falsy; everything else, `"false"`,
    /// `"0"`, `[]` and `{}` included, is truthy.
    static func isTruthy(_ value: JSON) -> Bool {
        switch value.type {
        case .bool:
            return value.boolValue
        case .number:
            let number = value.doubleValue
            return number != 0 && !number.isNaN
        case .string:
            return !value.stringValue.isEmpty
        case .array, .dictionary:
            return true
        default:
            return false
        }
    }

    /// `JSON.stringify(a) === JSON.stringify(b)`: same types and values all the way down, with
    /// `1` and `1.0` equal. Object key order is not compared, as `JSON` does not keep it.
    static func isJSONEqual(_ a: JSON, _ b: JSON) -> Bool {
        switch (a.type, b.type) {
        case (.null, .null):
            return true
        case (.string, .string):
            return a.stringValue == b.stringValue
        case (.number, .number):
            return a.doubleValue == b.doubleValue
        case (.bool, .bool):
            return a.boolValue == b.boolValue
        case (.array, .array):
            let left = a.arrayValue, right = b.arrayValue
            return left.count == right.count && zip(left, right).allSatisfy { isJSONEqual($0, $1) }
        case (.dictionary, .dictionary):
            let left = a.dictionaryValue, right = b.dictionaryValue
            return left.count == right.count && left.allSatisfy { key, value in
                right[key].map { isJSONEqual(value, $0) } ?? false
            }
        default:
            return false
        }
    }

    private static func number(_ string: String) -> Double {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return 0 }
        switch trimmed {
        case "Infinity", "+Infinity": return .infinity
        case "-Infinity": return -.infinity
        default: break
        }
        let lower = trimmed.lowercased()
        for (prefix, radix) in [("0x", 16), ("0o", 8), ("0b", 2)] where lower.hasPrefix(prefix) {
            let digits = lower.dropFirst(2)
            guard !digits.isEmpty, digits.allSatisfy({ $0.isHexDigit && Int(String($0), radix: 16)! < radix }) else { return .nan }
            return digits.reduce(0.0) { $0 * Double(radix) + Double(Int(String($1), radix: 16)!) }
        }
        let decimal = "^[+-]?([0-9]+\\.?[0-9]*|\\.[0-9]+)([eE][+-]?[0-9]+)?$"
        guard trimmed.range(of: decimal, options: .regularExpression) != nil else { return .nan }
        return Double(trimmed) ?? .nan
    }

    /// `Number.prototype.toString()`: shortest round-trip digits, plain notation for exponents
    /// from -7 to 20, otherwise `1.5e+21` / `1e-7`.
    private static func numberString(_ number: Double) -> String {
        if number.isNaN { return "NaN" }
        if number.isInfinite { return number < 0 ? "-Infinity" : "Infinity" }
        if number == 0 { return "0" }
        let sign = number < 0 ? "-" : ""

        // Swift's description is the shortest round-trip form, e.g. "1.5", "100.0", "1e-07".
        let parts = "\(abs(number))".lowercased().split(separator: "e")
        let exponent = parts.count > 1 ? Int(parts[1])! : 0
        let mantissa = parts[0].split(separator: ".", omittingEmptySubsequences: false)
        let integerDigits = String(mantissa[0])
        var digits = integerDigits + (mantissa.count > 1 ? String(mantissa[1]) : "")
        var point = integerDigits.count + exponent
        while digits.hasPrefix("0") { digits.removeFirst(); point -= 1 }
        while digits.hasSuffix("0") { digits.removeLast() }

        let count = digits.count
        let body: String
        if count <= point && point <= 21 {
            body = digits + String(repeating: "0", count: point - count)
        } else if 0 < point && point <= 21 {
            body = String(digits.prefix(point)) + "." + String(digits.dropFirst(point))
        } else if -6 < point && point <= 0 {
            body = "0." + String(repeating: "0", count: -point) + digits
        } else {
            let e = point - 1
            let fraction = count > 1 ? "." + String(digits.dropFirst()) : ""
            body = String(digits.prefix(1)) + fraction + "e" + (e < 0 ? "-" : "+") + String(abs(e))
        }
        return sign + body
    }
}
