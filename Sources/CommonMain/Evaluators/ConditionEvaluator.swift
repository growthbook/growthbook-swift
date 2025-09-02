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
    func isEvalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil) -> Bool {
        // Processing null values - handling this case separately
        if conditionValue.type == .null {
            return attributeValue == nil || attributeValue?.type == .null
        }
        
        // Protection from nil values
        let unwrappedAttribute = attributeValue ?? .null
        
        // String comparison
        if conditionValue.type == .string && unwrappedAttribute.type == .string {
            return conditionValue.stringValue == unwrappedAttribute.stringValue
        }
        
        // Number comparison
        if conditionValue.type == .number && unwrappedAttribute.type == .number {
            return conditionValue.doubleValue == unwrappedAttribute.doubleValue
        }
        
        // Boolean comparison
        if conditionValue.type == .bool && unwrappedAttribute.type == .bool {
            return conditionValue.boolValue == unwrappedAttribute.boolValue
        }
        
        // Array comparison - more detailed with deep equality check
        if let conditionArray = conditionValue.array {
            if let attributeArray = unwrappedAttribute.array {
                if conditionArray.count == attributeArray.count {
                    // Compare each array element to check for deep equality
                    for i in 0..<conditionArray.count {
                        if !isEvalConditionValue(conditionValue: conditionArray[i],
                                               attributeValue: attributeArray[i],
                                               savedGroups: savedGroups) {
                            return false
                        }
                    }
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }
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
            } else if let _ = unwrappedAttribute.dictionary {
                // For regular objects, perform deep comparison
                // (assuming that Common.isEqual() already performs deep comparison)
                return Common.isEqual(conditionValue, unwrappedAttribute)
            } else {
                return false
            }
        }
        
        // If nothing worked, return to simple comparison
        return conditionValue == unwrappedAttribute
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

        /// There are three operators where conditionValue is an array
        if let conditionValue = conditionJson.array, attributeValue != .null {
            switch operatorKey {
            case "$in":
                return Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$nin":
                return !Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$all":
                if let attributeValue = attributeValue.array {
                    // Loop through conditionValue array
                    // If none of the elements in the attributeValue array pass evalConditionValue(conditionValue[i], attributeValue[j]), return false
                    for con in conditionValue {
                        var result = false
                        for attribute in attributeValue {
                            if isEvalConditionValue(conditionValue: con, attributeValue: attribute, savedGroups: savedGroups) {
                                result = true
                            }
                        }
                        if !result {
                            return result
                        }
                    }
                    return true
                } else {
                    // If attributeValue is not an array, return false
                    return false
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
            case "$veq":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) == Utils.paddedVersionString(input: conditionString)
                }
            case "$vne":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) != Utils.paddedVersionString(input: conditionString)
                }
            case "$vgt":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) > Utils.paddedVersionString(input: conditionString)
                }
            case "$vgte":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) >= Utils.paddedVersionString(input: conditionString)
                }
            case "$vlt":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) < Utils.paddedVersionString(input: conditionString)
                }
            case "$vlte":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.paddedVersionString(input: attributeString) <= Utils.paddedVersionString(input: conditionString)
                }
            case "$inGroup":
                if attributeValue != .null, let conditionString = conditionValue.string {
                    return Common.isIn(actual: attributeValue, expected: savedGroups?[conditionString].array ?? [] )
                }
            case "$notInGroup": 
                if attributeValue != .null, let conditionString = conditionValue.string {
                    return !Common.isIn(actual: attributeValue, expected: savedGroups?[conditionString].array ?? [])
                }
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
                        }
                        return false
                    }
                    if let num = attributeValue.double {
                        if let cond = conditionValue.double {
                                    return num >= cond
                                } else if let condStr = conditionValue.string, let condNum = Double(condStr) {
                                    return num > condNum
                                }
                                return false
                    }
                    if let str = attributeValue.string, let cond = conditionValue.string {
                        return str >= cond
                    }
                    return false
            // Evaluate REGEX operator - whether attribute contains condition regex
            case "$regex":
                let targetPrimitiveValueString = conditionValue.stringValue
                let sourcePrimitiveValueString = attributeValue.stringValue
                if isContains(source: sourcePrimitiveValueString, target: targetPrimitiveValueString) {
                    return true
                }
                return sourcePrimitiveValueString.contains(targetPrimitiveValueString)

            default: break
            }
        }
        return false
    }

    private func isContains(source: String, target: String) -> Bool {
        let convertedItem = target.replacingOccurrences(of: "([^\\\\])\\/", with: "$1\\/")
        
        do {
            let regex = try NSRegularExpression(pattern: convertedItem)
            let range = NSRange(location: 0, length: source.utf16.count)
            let isMatch = regex.firstMatch(in: source, options: [], range: range) != nil
            
            return isMatch
        } catch {
            return false
        }
    }

    private func isPrimitive(value: JSON) -> Bool {
        
        if value.number != nil || value.string != nil || value.bool != nil || value.int != nil || value == .null {
            return true
        }
        return false
    }
    
}
