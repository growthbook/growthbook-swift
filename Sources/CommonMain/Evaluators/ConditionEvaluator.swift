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
    /// This is the main function used to evaluate a condition.
    /// - attributes : User Attributes
    /// - condition : to be evaluated
    func isEvalCondition(attributes: JSON, conditionObj: JSON) -> Bool {
        if !conditionObj.arrayValue.isEmpty {
            return false
        }
        // If conditionObj has a key $or, return evalOr(attributes, condition["$or"])
        if let targetItems = conditionObj.dictionaryValue["$or"] {
            return isEvalOr(attributes: attributes, conditionObjs: targetItems.arrayValue)
        }

        // If conditionObj has a key $nor, return !evalOr(attributes, condition["$nor"])
        if let targetItems = conditionObj.dictionaryValue["$nor"] {
            return !isEvalOr(attributes: attributes, conditionObjs: targetItems.arrayValue)
        }

        // If conditionObj has a key $and, return !evalAnd(attributes, condition["$and"])
        if let targetItems = conditionObj.dictionaryValue["$and"] {
            return isEvalAnd(attributes: attributes, conditionObjs: targetItems.arrayValue)
        }

        // If conditionObj has a key $not, return !evalCondition(attributes, condition["$not"])
        if let targetItem = conditionObj.dictionaryValue["$not"] {
            return !isEvalCondition(attributes: attributes, conditionObj: targetItem)
        }

        // Loop through the conditionObj key/value pairs
        for key in conditionObj.dictionaryValue.keys {
            let element = getPath(obj: attributes, key: key)
            let value = conditionObj.dictionaryValue[key]
            if let value = value, !isEvalConditionValue(conditionValue: value, attributeValue: element) {
                // If evalConditionValue(value, getPath(attributes, key)) is false, break out of loop and return false
                return false
            }
        }
        // Return true
        return true
    }

    /// Evaluate OR conditions against given attributes
    func isEvalOr(attributes: JSON, conditionObjs: [JSON]) -> Bool {
        // If conditionObjs is empty, return true
        guard conditionObjs.isEmpty == false else {
            return true
        }
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is true, break out of the loop and return true
            if isEvalCondition(attributes: attributes, conditionObj: item) {
                return true
            }
        }

        // Return false
        return false
    }

    /// Evaluate AND conditions against given attributes
    func isEvalAnd(attributes: JSON, conditionObjs: [JSON]) -> Bool {
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is false, break out of the loop and return false
            if !isEvalCondition(attributes: attributes, conditionObj: item) {
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
    func isEvalConditionValue(conditionValue: JSON, attributeValue: JSON?) -> Bool {
        // If conditionValue is a string, number, boolean, return true if it's "equal" to attributeValue and false if not.
        var unwrappedAttribute = attributeValue
        
        if attributeValue == nil {
            unwrappedAttribute = .null
        }
        
        if let unwrappedAttribute = unwrappedAttribute {
            if isPrimitive(value: conditionValue) && isPrimitive(value: unwrappedAttribute) {
                return conditionValue == unwrappedAttribute
            }
        } else if isPrimitive(value: conditionValue) {
            return false
        }

        // If conditionValue is array, return true if it's "equal" - "equal" should do a deep comparison for arrays.
        if let conditionValue = conditionValue.array {

            if let attributeValue = attributeValue?.array {
                if conditionValue.count == attributeValue.count {
                    return conditionValue == attributeValue
                } else {
                    return false
                }
            } else {
                return false
            }
        }

        // If conditionValue is an object, loop over each key/value pair:
        if let _ = conditionValue.dictionary {

            if isOperatorObject(obj: conditionValue) {
                for key in conditionValue.dictionaryValue.keys {
                    // If evalOperatorCondition(key, attributeValue, value) is false, return false
                    if let value = conditionValue.dictionaryValue[key], !isEvalOperatorCondition(operatorKey: key, attributeValue: attributeValue, conditionValue: value) {
                        return false
                    }
                }
            } else if attributeValue != nil {
                return isEqual(conditionValue, attributeValue)  //conditionValue.equals(attributeValue)
            } else {
                return false
            }
        }

        // Return true
        return true
    }

    /// This checks if attributeValue is an array, and if so at least one of the array items must match the condition
    func isElemMatch(attributeValue: [JSON], condition: JSON) -> Bool {

        // Loop through items in attributeValue
        for item in attributeValue {
            // If isOperatorObject(condition)
            if isOperatorObject(obj: condition) {
                // If evalConditionValue(condition, item), break out of loop and return true
                if isEvalConditionValue(conditionValue: condition, attributeValue: item) {
                    return true
                }
            }
            // Else if evalCondition(item, condition), break out of loop and return true
            else if isEvalCondition(attributes: item, conditionObj: condition) {
                return true
            }
        }

        // If attributeValue is not an array, return false
        return false
    }

    /// This function is just a case statement that handles all the possible operators
    ///
    /// There are basic comparison operators in the form attributeValue {op} conditionValue
    func isEvalOperatorCondition(operatorKey: String, attributeValue: JSON?, conditionValue: JSON) -> Bool {
        let conditionJson = JSON(conditionValue)
        // Evaluate TYPE operator - whether both are of same type
        if operatorKey == "$type" {
            return getType(obj: attributeValue) == conditionJson.stringValue
        }

        // Evaluate NOT operator - whether condition doesn't contain attribute
        if operatorKey == "$not" {
            return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue)
        }

        // Evaluate EXISTS operator - whether condition contains attribute
        if operatorKey == "$exists" {
            let targetPrimitiveValue = conditionJson.stringValue
            if targetPrimitiveValue == "false" && attributeValue == nil {
                return true
            } else if targetPrimitiveValue == "true" && attributeValue != nil {
                return true
            }
        }

        switch operatorKey {
        case "$type":
            return  getType(obj: attributeValue) == conditionJson.stringValue
        case "$not":
            if let conditionValue = conditionValue.dictionaryValue.values.first {
                return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue)
            }
        case "$exists":
            let targetPrimitiveValue = conditionJson.stringValue
            if targetPrimitiveValue == "false" && attributeValue == nil {
                return true
            } else if targetPrimitiveValue == "true" && attributeValue != nil {
                return true
            }
        default: break
        }

        /// There are three operators where conditionValue is an array
        if let conditionValue = conditionJson.array, let attributeValue = attributeValue {
            switch operatorKey {
            case "$in":
                return conditionValue.contains(attributeValue)
            case "$nin":
                return !conditionValue.contains(attributeValue)
            case "$all":
                if let attributeValue = attributeValue.array {
                    // Loop through conditionValue array
                    // If none of the elements in the attributeValue array pass evalConditionValue(conditionValue[i], attributeValue[j]), return false
                    for con in conditionValue {
                        var result = false
                        for attribute in attributeValue {
                            if isEvalConditionValue(conditionValue: con, attributeValue: attribute) {
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
        } else if let attribute = attributeValue?.array {
            switch operatorKey {
            // Evaluate ELEMMATCH operator - whether condition matches attribute
            case "$elemMatch":
                return  isElemMatch(attributeValue: attribute, condition: conditionValue)
            // Evaluate SIE operator - whether condition size is same as that of attribute
            case "$size":
                return isEvalConditionValue(conditionValue: conditionValue, attributeValue: JSON(attribute.count))
            default: break
            }
        } else if let attributeValue = attributeValue {
            let targetPrimitiveValue = conditionValue
            let sourcePrimitiveValue = attributeValue
            switch operatorKey {
            case "$veq":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) == Utils.shared.paddedVersionString(input: conditionString)
                }
            case "$vne":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) != Utils.shared.paddedVersionString(input: conditionString)
                }
            case "$vgt":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) > Utils.shared.paddedVersionString(input: conditionString)
                }
            case "$vgte":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) >= Utils.shared.paddedVersionString(input: conditionString)
                }
            case "$vlt":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) < Utils.shared.paddedVersionString(input: conditionString)
                }
            case "$vlte":
                if let attributeString = attributeValue.string, let conditionString = conditionValue.string {
                    return Utils.shared.paddedVersionString(input: attributeString) <= Utils.shared.paddedVersionString(input: conditionString)
                }
            // Evaluate EQ operator - whether condition equals to attribute
            case "$eq":
                return  attributeValue == conditionValue
            // Evaluate NE operator - whether condition doesn't equal to attribute
            case "$ne":
                return  attributeValue != conditionValue
            // Evaluate LT operator - whether attribute less than to condition
            case "$lt":
                if let attributeDoubleOrNull = attributeValue.double, let conditionDoubleOrNull = conditionValue.double {
                    return attributeDoubleOrNull < conditionDoubleOrNull
                }
                return sourcePrimitiveValue < targetPrimitiveValue
            // Evaluate LTE operator - whether attribute less than or equal to condition
            case "$lte":
                if let attributeDoubleOrNull = attributeValue.double, let conditionDoubleOrNull = conditionValue.double {
                    return attributeDoubleOrNull <= conditionDoubleOrNull
                }
                return  sourcePrimitiveValue <= targetPrimitiveValue
            // Evaluate GT operator - whether attribute greater than to condition
            case "$gt":
                if let attributeDoubleOrNull = attributeValue.double, let conditionDoubleOrNull = conditionValue.double {
                    return attributeDoubleOrNull > conditionDoubleOrNull
                }
                return  sourcePrimitiveValue > targetPrimitiveValue
            // Evaluate GTE operator - whether attribute greater than or equal to condition
            case "$gte":
                if let attributeDoubleOrNull = attributeValue.double, let conditionDoubleOrNull = conditionValue.double {
                    return attributeDoubleOrNull >= conditionDoubleOrNull
                }
                return  sourcePrimitiveValue >= targetPrimitiveValue
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
        let arrayTarget = target.components(separatedBy: "|")
        if arrayTarget.isEmpty { return false }
        for item in arrayTarget {
            if source.contains(item) {
                return true
            }
        }

        return false
    }

    private func isPrimitive(value: JSON) -> Bool {
        
        if value.number != nil || value.string != nil || value.bool != nil || value.int != nil || value == .null {
            return true
        }
        return false
    }

    private func isEqual<T>(_ a: T, _ b: T) -> Bool where T : Equatable {
        return a == b
    }
}
