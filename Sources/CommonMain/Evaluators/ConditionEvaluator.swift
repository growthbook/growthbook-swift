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
    func isEvalCondition(attributes: JSON, conditionObj: JSON, savedGroups: JSON? = nil, visited: Set<String> = []) -> Bool {
        if !conditionObj.arrayValue.isEmpty {
            return false
        }
        // Condition is an object, keys are either specific operators or object paths values are either arguments for operators or conditions for paths
        for (key, value) in conditionObj.dictionaryValue {
            switch key {
            case "$or":
                guard isEvalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited) else { return false }
            case "$nor":
                guard !isEvalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited) else { return false }
            case "$and":
                guard isEvalAnd(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited) else { return false }
            case "$not":
                guard !isEvalCondition(attributes: attributes, conditionObj: value, savedGroups: savedGroups, visited: visited) else { return false }
            case "$savedGroup":
                guard evalSavedGroup(attributes: attributes, reference: value, savedGroups: savedGroups, visited: visited) else { return false }
            default:
                let element = getPath(obj: attributes, key: key)
                guard isEvalConditionValue(conditionValue: value, attributeValue: element, savedGroups: savedGroups, visited: visited) else { return false }
            }
        }
        // If none of the entries failed their checks, `evalCondition` returns true
        return true
    }

    /// Evaluate OR conditions against given attributes
    func isEvalOr(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?, visited: Set<String> = []) -> Bool {
        // If conditionObjs is empty, return true
        guard conditionObjs.isEmpty == false else {
            return true
        }
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is true, break out of the loop and return true
            if isEvalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups, visited: visited) {
                return true
            }
        }

        // Return false
        return false
    }

    /// Evaluate AND conditions against given attributes
    func isEvalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?, visited: Set<String> = []) -> Bool {
        // Loop through the conditionObjects
        for item in conditionObjs {
            // If evalCondition(attributes, conditionObjs[i]) is false, break out of the loop and return false
            if !isEvalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups, visited: visited) {
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
    func isEvalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil, insensitive: Bool = false, visited: Set<String> = []) -> Bool {
        // Processing null values - handling this case separately
        
        if insensitive,
               let condStr = conditionValue.string,
               let attrStr = attributeValue?.string {
                return condStr.lowercased() == attrStr.lowercased()
            }
        
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
                                               savedGroups: savedGroups, visited: visited) {
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
                                               savedGroups: savedGroups, visited: visited) {
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
    func isElemMatch(attributeValue: [JSON], condition: JSON, savedGroups: JSON?, visited: Set<String> = []) -> Bool {

        // Loop through items in attributeValue
        for item in attributeValue {
            // If isOperatorObject(condition)
            if isOperatorObject(obj: condition) {
                // If evalConditionValue(condition, item), break out of loop and return true
                if isEvalConditionValue(conditionValue: condition, attributeValue: item, savedGroups: savedGroups, visited: visited) {
                    return true
                }
            }
            // Else if evalCondition(item, condition), break out of loop and return true
            else if isEvalCondition(attributes: item, conditionObj: condition, savedGroups: savedGroups, visited: visited) {
                return true
            }
        }

        // If attributeValue is not an array, return false
        return false
    }

    /// This function is just a case statement that handles all the possible operators
    ///
    /// There are basic comparison operators in the form attributeValue {op} conditionValue
    func isEvalOperatorCondition(operatorKey: String, attributeValue: JSON, conditionValue: JSON, savedGroups: JSON? = nil, visited: Set<String> = []) -> Bool {
        let conditionJson = JSON(conditionValue)
        // Evaluate TYPE operator - whether both are of same type
        if operatorKey == "$type" {
            return getType(obj: attributeValue) == conditionJson.stringValue
        }

        // Evaluate NOT operator - whether condition doesn't contain attribute
        if operatorKey == "$not" {
            return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups, visited: visited)
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
                return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups, visited: visited)
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
        //
        // That negation does not hold for an entry these operators cannot read, and deliberately so:
        // both fail closed. Substituting an empty list would be the loud failure, since $notInGroup
        // would then pass everyone through an exclusion rule. See `savedGroupListValues`.
        switch operatorKey {
        case "$inGroup":
            guard let values = savedGroupListValues(conditionValue, savedGroups) else { return false }
            return Common.isIn(actual: attributeValue, expected: values)
        case "$notInGroup":
            guard let values = savedGroupListValues(conditionValue, savedGroups) else { return false }
            return !Common.isIn(actual: attributeValue, expected: values)
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

        /// There are three operators where conditionValue is an array
        if let conditionValue = conditionJson.array, attributeValue != .null {
            switch operatorKey {
            case "$in":
                return Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$ini":
                return Common.isIn(actual: attributeValue, expected: conditionValue, insensitive: true)
            case "$nin":
                return !Common.isIn(actual: attributeValue, expected: conditionValue)
            case "$nini":
                return !Common.isIn(actual: attributeValue, expected: conditionValue, insensitive: true)
            case "$all":
                return Common.isInAll(
                        actual: attributeValue,
                        expected: conditionValue,
                        savedGroups: savedGroups,
                        insensitive: true
                    ) { con, attr, groups in
                        isEvalConditionValue(conditionValue: con, attributeValue: attr, savedGroups: groups, insensitive: false, visited: visited)
                    }
            case "$alli":
                return Common.isInAll(
                        actual: attributeValue,
                        expected: conditionValue,
                        savedGroups: savedGroups,
                        insensitive: true
                    ) { con, attr, groups in
                        isEvalConditionValue(conditionValue: con, attributeValue: attr, savedGroups: groups, insensitive: true, visited: visited)
                    }
            default: break
            }
        } else if let attribute = attributeValue.array {
            switch operatorKey {
            // Evaluate ELEMMATCH operator - whether condition matches attribute
            case "$elemMatch":
                return  isElemMatch(attributeValue: attribute, condition: conditionValue, savedGroups: savedGroups, visited: visited)
            // Evaluate SIE operator - whether condition size is same as that of attribute
            case "$size":
                return isEvalConditionValue(conditionValue: conditionValue, attributeValue: JSON(attribute.count), savedGroups: savedGroups, visited: visited)
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
    
    /// Resolves a `$savedGroup` reference: is the user a member of the group it names?
    ///
    /// Unlike `$inGroup`, this is a top-level operator with no attribute of its own, so the entry
    /// decides what membership means — a list entry names the attribute to test, and a condition
    /// entry is evaluated in full.
    ///
    /// Anything this SDK cannot make sense of matches nobody rather than throwing. A payload is
    /// allowed to be newer than the SDK reading it, and a group type added later must neither take
    /// the host app down nor quietly let everyone through.
    ///
    /// [visited] holds the ids currently being resolved, so a group that references itself —
    /// directly or along a chain — stops instead of recursing forever.
    ///
    /// Lookups go through `JSON`'s key subscript rather than `.dictionary`, which copies the whole
    /// object it is read from. A condition chain resolves one group per step, so reading the
    /// payload through `.dictionary` here copied every saved group in it once per step.
    private func evalSavedGroup(attributes: JSON, reference: JSON, savedGroups: JSON?, visited: Set<String>) -> Bool {
        // The operator takes an object; a bare id string or an array is not one
        guard reference.type == .dictionary else { return false }
        guard let id = reference["id"].string, !visited.contains(id) else { return false }

        // An override that is present but unusable is not ignored: falling back to the entry's own
        // attribute would test a different population than the payload asked for.
        var overrideKey: String? = nil
        let rawKey = reference["attributeKey"]
        if rawKey.exists() {
            guard let key = rawKey.string else { return false }
            overrideKey = key
        }

        // Absent from the payload, or a v1 bare array, which carries neither a type to act on nor
        // an attribute for this operator to use
        guard let savedGroups else { return false }
        let entry = savedGroups[id]
        guard entry.type == .dictionary else { return false }

        switch entry["type"].string {
        case "list":
            guard let key = overrideKey ?? entry["attributeKey"].string,
                  let values = entry["values"].array else { return false }
            return Common.isIn(actual: getPath(obj: attributes, key: key) ?? .null, expected: values)

        // A condition group has no single attribute, so an override has nothing to override
        case "condition":
            let condition = entry["condition"]
            guard condition.type == .dictionary else { return false }
            return isEvalCondition(attributes: attributes, conditionObj: condition, savedGroups: savedGroups, visited: visited.union([id]))

        // A group type added after this SDK was built
        default:
            return false
        }
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

    /// The values `$inGroup` / `$notInGroup` compare against, or `nil` when the entry carries none
    /// and both operators must therefore fail closed.
    ///
    /// A `savedGroups` entry is either the bare array these operators were built for, or a
    /// `savedGroupReferencesV2` typed entry. Only the list flavour of the latter has values to
    /// offer: a condition group is resolved through `$savedGroup`, which knows how to evaluate it
    /// and where to find an attribute for it — neither of which is true here.
    ///
    /// The split between an absent id and an unreadable entry is deliberate. An unknown group id, a
    /// missing `savedGroups` object, and a group id that is not a string all resolve to an empty
    /// list, so membership is simply false and `$notInGroup` keeps passing — documented behaviour
    /// every SDK implements, with its own conformance case. An entry that is present but cannot be
    /// read resolves to `nil` instead, which the call site turns into false for both operators.
    ///
    /// The lookup goes through `JSON`'s key subscript, which is a dictionary hit, rather than
    /// `.dictionary`, which copies every entry in the payload before one of them is read.
    /// `exists()` is what separates an absent id from a present one, since the subscript answers
    /// with a null `JSON` either way and only marks the former with an error.
    private func savedGroupListValues(_ conditionValue: JSON, _ savedGroups: JSON?) -> [JSON]? {
        guard let groupId = conditionValue.string, let savedGroups else { return [] }

        let entry = savedGroups[groupId]
        guard entry.exists() else { return [] }

        if let array = entry.array { return array }
        if entry.type == .dictionary, entry["type"].string == "list" { return entry["values"].array }
        return nil
    }

    private func isPrimitive(value: JSON) -> Bool {
        
        if value.number != nil || value.string != nil || value.bool != nil || value.int != nil || value == .null {
            return true
        }
        return false
    }
    
}
