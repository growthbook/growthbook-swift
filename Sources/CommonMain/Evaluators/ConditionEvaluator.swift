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
        // Only a definite pass counts. An undecided (unknown) result fails.
        evalCondition(attributes: attributes, conditionObj: conditionObj, savedGroups: savedGroups) == true
    }

    /// Evaluates a condition to `true`, `false`, or `nil` when the result depends on an operator
    /// this SDK doesn't support. `nil` stays `nil` under `$not` and `$nor`, so negating an
    /// unsupported condition can't make it pass for everyone.
    func evalCondition(attributes: JSON, conditionObj: JSON, savedGroups: JSON? = nil) -> Bool? {
        if !conditionObj.arrayValue.isEmpty {
            return false
        }
        var result: Bool? = true
        // Condition is an object, keys are either specific operators or object paths values are either arguments for operators or conditions for paths
        for (key, value) in conditionObj.dictionaryValue {
            let entry: Bool?
            switch key {
            case "$or":
                entry = evalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups)
            case "$nor":
                entry = negate(evalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups))
            case "$and":
                entry = evalAnd(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups)
            case "$not":
                entry = negate(evalCondition(attributes: attributes, conditionObj: value, savedGroups: savedGroups))
            default:
                let element = getPath(obj: attributes, key: key)
                entry = evalConditionValue(conditionValue: value, attributeValue: element, savedGroups: savedGroups)
            }
            // One failing entry decides it, wherever an unsupported one is
            if entry == false { return false }
            if entry == nil { result = nil }
        }
        return result
    }

    /// Evaluate OR conditions against given attributes
    func isEvalOr(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool {
        evalOr(attributes: attributes, conditionObjs: conditionObjs, savedGroups: savedGroups) == true
    }

    private func evalOr(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool? {
        // If conditionObjs is empty, return true
        guard conditionObjs.isEmpty == false else {
            return true
        }
        var result: Bool? = false
        for item in conditionObjs {
            let entry = evalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups)
            if entry == true { return true }
            if entry == nil { result = nil }
        }
        return result
    }

    /// Evaluate AND conditions against given attributes
    func isEvalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool {
        evalAnd(attributes: attributes, conditionObjs: conditionObjs, savedGroups: savedGroups) == true
    }

    private func evalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool? {
        var result: Bool? = true
        for item in conditionObjs {
            let entry = evalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups)
            if entry == false { return false }
            if entry == nil { result = nil }
        }
        return result
    }

    /// Negation that keeps an undecided result undecided.
    private func negate(_ value: Bool?) -> Bool? {
        value.map { !$0 }
    }

    /// Keys that belong on a condition rather than on a value. Used as operators on a value they
    /// never match, and `$elemMatch` treats a value using them as a condition on each item's fields.
    private static let conditionOperators: Set<String> = ["$or", "$nor", "$and", "$savedGroup"]

    /// Operators this SDK evaluates on a value. Any other `$` key is unsupported.
    private static let valueOperators: Set<String> = [
        "$type", "$not", "$exists", "$inGroup", "$notInGroup",
        "$veq", "$vne", "$vgt", "$vgte", "$vlt", "$vlte",
        "$eq", "$ne", "$lt", "$lte", "$gt", "$gte",
        "$regex", "$regexi", "$notRegex", "$notRegexi",
        "$in", "$ini", "$nin", "$nini", "$all", "$alli", "$elemMatch", "$size",
    ]

    /// True if the value is an object whose keys all start with `$`. An empty object has no
    /// operators, so as a condition value it always passes.
    func isOperatorObject(obj: JSON) -> Bool {
        guard let value = obj.dictionary else { return false }
        return value.keys.allSatisfy { $0.first == "$" }
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
        evalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups, insensitive: insensitive) == true
    }

    /// Tri-state form of `isEvalConditionValue`: `nil` when an unsupported operator decides it.
    func evalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil, insensitive: Bool = false) -> Bool? {
        // Processing null values - handling this case separately
        
        if insensitive,
               let condStr = conditionValue.string,
               let attrStr = attributeValue?.string {
                return Common.sameCodeUnits(condStr.lowercased(), attrStr.lowercased())
            }
        
        if conditionValue.type == .null {
            return attributeValue == nil || attributeValue?.type == .null
        }
        
        // Protection from nil values
        let unwrappedAttribute = attributeValue ?? .null
        
        // String comparison
        if conditionValue.type == .string && unwrappedAttribute.type == .string {
            return Common.sameCodeUnits(conditionValue.stringValue, unwrappedAttribute.stringValue)
        }
        
        // Number comparison
        if conditionValue.type == .number && unwrappedAttribute.type == .number {
            return conditionValue.doubleValue == unwrappedAttribute.doubleValue
        }
        
        // Boolean comparison
        if conditionValue.type == .bool && unwrappedAttribute.type == .bool {
            return conditionValue.boolValue == unwrappedAttribute.boolValue
        }
        
        // An array condition is a literal value: deep equality, like JS's JSON comparison. Its
        // items are values, not conditions, so an object inside it isn't read as operators.
        if conditionValue.array != nil {
            return isStrictlyEqual(conditionValue, unwrappedAttribute)
        }
        
        // Processing condition objects
        if let _ = conditionValue.dictionary {
            if isOperatorObject(obj: conditionValue) {
                var result: Bool? = true
                for (key, value) in conditionValue.dictionaryValue {
                    let entry = evalOperatorCondition(operatorKey: key,
                                                      attributeValue: unwrappedAttribute,
                                                      conditionValue: value,
                                                      savedGroups: savedGroups)
                    if entry == false { return false }
                    if entry == nil { result = nil }
                }
                return result
            } else if let _ = unwrappedAttribute.dictionary {
                return isStrictlyEqual(conditionValue, unwrappedAttribute)
            } else {
                return false
            }
        }
        
        // If nothing worked, return to simple comparison
        return conditionValue == unwrappedAttribute
    }

    /// This checks if attributeValue is an array, and if so at least one of the array items must match the condition
    func isElemMatch(attributeValue: [JSON], condition: JSON, savedGroups: JSON?) -> Bool {
        elemMatch(attributeValue: attributeValue, condition: condition, savedGroups: savedGroups) == true
    }

    private func elemMatch(attributeValue: [JSON], condition: JSON, savedGroups: JSON?) -> Bool? {
        // Operators test each item itself. A condition, including one that only uses
        // $or, $and, $nor or $savedGroup, tests each item's fields.
        let testsItself = isOperatorObject(obj: condition)
            && !condition.dictionaryValue.keys.contains { Self.conditionOperators.contains($0) }
        var result: Bool? = false
        for item in attributeValue {
            // Only null items are skipped; 0, "" and false are still tested
            if item.type == .null { continue }
            let entry = testsItself
                ? evalConditionValue(conditionValue: condition, attributeValue: item, savedGroups: savedGroups)
                : evalCondition(attributes: item, conditionObj: condition, savedGroups: savedGroups)
            if entry == true { return true }
            if entry == nil { result = nil }
        }
        return result
    }

    /// This function is just a case statement that handles all the possible operators
    ///
    /// There are basic comparison operators in the form attributeValue {op} conditionValue
    func isEvalOperatorCondition(operatorKey: String, attributeValue: JSON, conditionValue: JSON, savedGroups: JSON? = nil) -> Bool {
        evalOperatorCondition(operatorKey: operatorKey, attributeValue: attributeValue, conditionValue: conditionValue, savedGroups: savedGroups) == true
    }

    /// Tri-state form of `isEvalOperatorCondition`: `nil` for an operator this SDK doesn't support.
    func evalOperatorCondition(operatorKey: String, attributeValue: JSON, conditionValue: JSON, savedGroups: JSON? = nil) -> Bool? {
        // Keys that belong on a condition never match as an operator on a value. Any other
        // unknown operator is undecided.
        guard Self.valueOperators.contains(operatorKey) else {
            return Self.conditionOperators.contains(operatorKey) ? false : nil
        }
        let conditionJson = JSON(conditionValue)
        // Evaluate TYPE operator - whether both are of same type
        if operatorKey == "$type" {
            return getType(obj: attributeValue) == conditionJson.stringValue
        }

        // Evaluate NOT operator - whether condition doesn't contain attribute
        if operatorKey == "$not" {
            return negate(evalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups))
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

        // The version operators are handled before the dispatch below, which branches on the shape of
        // the attribute and would otherwise leave them unreachable for array or absent attributes.
        // Both sides must be strings, or both numbers. Anything else is a type mismatch: the operator
        // fails, except $vne, which is the negation of $veq and so matches.
        if Self.versionOperators.contains(operatorKey), !isOrderable(attributeValue, conditionValue) {
            return operatorKey == "$vne"
        }
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

        // Equality, ordering and regex operators work for any attribute shape, so they are decided
        // here rather than in the shape dispatch below. Types are strict: no coercion between
        // strings, numbers and booleans, so a mismatch fails the positive operator and $ne matches.
        switch operatorKey {
        case "$eq":
            return isStrictlyEqual(attributeValue, conditionValue)
        case "$ne":
            return !isStrictlyEqual(attributeValue, conditionValue)
        case "$lt", "$lte", "$gt", "$gte":
            return compareOrdered(operatorKey: operatorKey, attributeValue: attributeValue, conditionValue: conditionValue)
        case "$regex", "$regexi", "$notRegex", "$notRegexi":
            // Only strings are matched against a pattern. The negated forms match a non-string,
            // like `$not: { $regex }` does.
            guard let source = attributeValue.string else {
                return operatorKey.hasPrefix("$not")
            }
            // A pattern that isn't a string is malformed, like one that doesn't compile, so
            // neither form matches. `stringValue` would turn it into an empty pattern that
            // matches every string.
            guard let pattern = conditionValue.string else {
                return false
            }
            return isContains(
                source: source,
                target: pattern,
                insensitive: operatorKey.hasSuffix("i"),
                negate: operatorKey.hasPrefix("$not")
            )
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
            case "$all", "$alli":
                return isInAll(actual: attributeValue, expected: conditionValue, savedGroups: savedGroups, insensitive: operatorKey == "$alli")
            default: break
            }
        } else if let attribute = attributeValue.array {
            switch operatorKey {
            // Evaluate ELEMMATCH operator - whether condition matches attribute
            case "$elemMatch":
                return elemMatch(attributeValue: attribute, condition: conditionValue, savedGroups: savedGroups)
            // Evaluate SIE operator - whether condition size is same as that of attribute
            case "$size":
                return evalConditionValue(conditionValue: conditionValue, attributeValue: JSON(attribute.count), savedGroups: savedGroups)
            default: break
            }
        }
        return false
    }

    private static let versionOperators: Set<String> = ["$veq", "$vne", "$vgt", "$vgte", "$vlt", "$vlte"]

    /// Ordering only applies between two strings or two numbers. Booleans are not ordered, and a
    /// missing or null attribute has nothing to compare.
    private func isOrderable(_ attributeValue: JSON, _ conditionValue: JSON) -> Bool {
        (attributeValue.type == .string || attributeValue.type == .number) && attributeValue.type == conditionValue.type
    }

    /// Evaluates `$lt`, `$lte`, `$gt` and `$gte`. Two numbers compare numerically and two strings
    /// compare as text by UTF-16 code unit, like JavaScript, so `"10" < "9"`. Any other pair fails.
    private func compareOrdered(operatorKey: String, attributeValue: JSON, conditionValue: JSON) -> Bool {
        guard isOrderable(attributeValue, conditionValue) else { return false }

        let isLess: Bool
        let isEqual: Bool
        if attributeValue.type == .number {
            let attr = attributeValue.doubleValue
            let cond = conditionValue.doubleValue
            isLess = attr < cond
            isEqual = attr == cond
        } else {
            let attr = attributeValue.stringValue.utf16
            let cond = conditionValue.stringValue.utf16
            isLess = attr.lexicographicallyPrecedes(cond)
            isEqual = attr.elementsEqual(cond)
        }

        switch operatorKey {
        case "$lt": return isLess
        case "$lte": return isLess || isEqual
        case "$gt": return !isLess && !isEqual
        default: return !isLess
        }
    }

    /// Tri-state `$all`/`$alli`, as JS `isInAll`: every expected value must match some element.
    /// An element that can't be decided leaves that value undecided unless another element matches.
    private func isInAll(actual: JSON, expected: [JSON], savedGroups: JSON?, insensitive: Bool) -> Bool? {
        guard let actualArray = actual.array else { return false }
        var result: Bool? = true
        for expectedItem in expected {
            var passed: Bool? = false
            for actualItem in actualArray {
                let entry = evalConditionValue(conditionValue: expectedItem, attributeValue: actualItem, savedGroups: savedGroups, insensitive: insensitive)
                if entry == true {
                    passed = true
                    break
                }
                if entry == nil { passed = nil }
            }
            if passed == false { return false }
            if passed == nil { result = nil }
        }
        return result
    }

    /// Deep equality without coercion. `JSON`'s own `==` compares arrays and objects as
    /// `NSArray`/`NSDictionary`, which bridges booleans to `NSNumber` and treats `true` as `1`.
    func isStrictlyEqual(_ lhs: JSON, _ rhs: JSON) -> Bool {
        switch (lhs.type, rhs.type) {
        case (.number, .number):
            return lhs.doubleValue == rhs.doubleValue
        case (.string, .string):
            return Common.sameCodeUnits(lhs.stringValue, rhs.stringValue)
        case (.bool, .bool):
            return lhs.boolValue == rhs.boolValue
        case (.null, .null):
            return true
        case (.array, .array):
            let left = lhs.arrayValue
            let right = rhs.arrayValue
            return left.count == right.count && zip(left, right).allSatisfy { isStrictlyEqual($0, $1) }
        case (.dictionary, .dictionary):
            let left = lhs.dictionaryValue
            let right = rhs.dictionaryValue
            return left.count == right.count && left.allSatisfy { key, value in
                guard let other = right[key] else { return false }
                return isStrictlyEqual(value, other)
            }
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
