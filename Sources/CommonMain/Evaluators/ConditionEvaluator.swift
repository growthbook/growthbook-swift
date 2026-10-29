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
    func evalCondition(attributes: JSON, conditionObj: JSON, savedGroups: JSON? = nil, visited: Set<String> = []) -> Bool? {
        if !conditionObj.arrayValue.isEmpty {
            return false
        }
        var result: Bool? = true
        // Condition is an object, keys are either specific operators or object paths values are either arguments for operators or conditions for paths
        for (key, value) in conditionObj.dictionaryValue {
            let entry: Bool?
            switch key {
            case "$or":
                entry = evalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited)
            case "$nor":
                entry = negate(evalOr(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited))
            case "$and":
                entry = evalAnd(attributes: attributes, conditionObjs: value.arrayValue, savedGroups: savedGroups, visited: visited)
            case "$not":
                entry = negate(evalCondition(attributes: attributes, conditionObj: value, savedGroups: savedGroups, visited: visited))
            case "$savedGroup":
                entry = evalSavedGroup(attributes: attributes, reference: value, savedGroups: savedGroups, visited: visited)
            default:
                let element = getPath(obj: attributes, key: key)
                entry = evalConditionValue(conditionValue: value, attributeValue: element, savedGroups: savedGroups, visited: visited)
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

    private func evalOr(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?, visited: Set<String> = []) -> Bool? {
        // If conditionObjs is empty, return true
        guard conditionObjs.isEmpty == false else {
            return true
        }
        var result: Bool? = false
        for item in conditionObjs {
            let entry = evalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups, visited: visited)
            if entry == true { return true }
            if entry == nil { result = nil }
        }
        return result
    }

    /// Evaluate AND conditions against given attributes
    func isEvalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?) -> Bool {
        evalAnd(attributes: attributes, conditionObjs: conditionObjs, savedGroups: savedGroups) == true
    }

    private func evalAnd(attributes: JSON, conditionObjs: [JSON], savedGroups: JSON?, visited: Set<String> = []) -> Bool? {
        var result: Bool? = true
        for item in conditionObjs {
            let entry = evalCondition(attributes: attributes, conditionObj: item, savedGroups: savedGroups, visited: visited)
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

    /// Given attributes and a dot-separated path string, return the value at that path, or `nil` if
    /// the path doesn't exist. Like JS, only own keys are read: an object's keys, and an array's
    /// indices (`"0"`, `"1"`, ...) and `"length"`. Strings and other primitives have none.
    func getPath(obj: JSON, key: String) -> JSON? {
        var element = obj

        for path in key.components(separatedBy: ".") {
            if let array = element.array {
                guard let value = arrayOwnProperty(array, path) else { return nil }
                element = value
            } else if let dict = element.dictionary, let value = dict[path] {
                element = value
            } else {
                return nil
            }
        }
        return element
    }

    /// An array's own property `key`: `length`, or the item at a canonical index such as `"1"`
    /// (not `"01"` or `"+1"`), as JS reads `array[key]`.
    private func arrayOwnProperty(_ array: [JSON], _ key: String) -> JSON? {
        if key == "length" {
            return JSON(array.count)
        }
        guard let index = Int(key), index >= 0, index < array.count, String(index) == key else {
            return nil
        }
        return array[index]
    }

    /// Evaluates Condition Value against given condition & attributes
    func isEvalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil, insensitive: Bool = false) -> Bool {
        evalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups, insensitive: insensitive) == true
    }

    /// Tri-state form of `isEvalConditionValue`: `nil` when an unsupported operator decides it.
    func evalConditionValue(conditionValue: JSON, attributeValue: JSON?, savedGroups: JSON? = nil, insensitive: Bool = false, visited: Set<String> = []) -> Bool? {
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
                                                      savedGroups: savedGroups,
                                                      visited: visited)
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

    private func elemMatch(attributeValue: [JSON], condition: JSON, savedGroups: JSON?, visited: Set<String> = []) -> Bool? {
        // Operators test each item itself. A condition, including one that only uses
        // $or, $and, $nor or $savedGroup, tests each item's fields.
        let testsItself = isOperatorObject(obj: condition)
            && !condition.dictionaryValue.keys.contains { Self.conditionOperators.contains($0) }
        var result: Bool? = false
        for item in attributeValue {
            // Only null items are skipped; 0, "" and false are still tested
            if item.type == .null { continue }
            let entry = testsItself
                ? evalConditionValue(conditionValue: condition, attributeValue: item, savedGroups: savedGroups, visited: visited)
                : evalCondition(attributes: item, conditionObj: condition, savedGroups: savedGroups, visited: visited)
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
    func evalOperatorCondition(operatorKey: String, attributeValue: JSON, conditionValue: JSON, savedGroups: JSON? = nil, visited: Set<String> = []) -> Bool? {
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
            return negate(evalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups, visited: visited))
        }

        // Evaluate EXISTS operator - whether condition contains attribute. The value is read as a JS
        // boolean, so `$exists: 1` asks for a present attribute and `0` or "" for an absent one.
        if operatorKey == "$exists" {
            let present = attributeValue.type != .null
            return isJsTruthy(conditionValue) ? present : !present
        }

        switch operatorKey {
        case "$type":
            return  getType(obj: attributeValue) == conditionJson.stringValue
        case "$not":
            if let conditionValue = conditionValue.dictionaryValue.values.first {
                return !isEvalConditionValue(conditionValue: conditionValue, attributeValue: attributeValue, savedGroups: savedGroups)
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
        // both fail closed, and a group type added after this SDK is undecided. Substituting an empty
        // list would be the loud failure, since $notInGroup would then pass everyone through an
        // exclusion rule. See `savedGroupListValues`.
        if operatorKey == "$inGroup" || operatorKey == "$notInGroup" {
            if isNewGroupType(conditionValue, savedGroups) { return nil }
            guard let values = savedGroupListValues(conditionValue, savedGroups) else { return false }
            let isMember = Common.isIn(actual: attributeValue, expected: values)
            return operatorKey == "$inGroup" ? isMember : !isMember
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
            return isIdentical(attributeValue, conditionValue)
        case "$ne":
            return !isIdentical(attributeValue, conditionValue)
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
                return isInAll(actual: attributeValue, expected: conditionValue, savedGroups: savedGroups, insensitive: operatorKey == "$alli", visited: visited)
            default: break
            }
        } else if let attribute = attributeValue.array {
            switch operatorKey {
            // Evaluate ELEMMATCH operator - whether condition matches attribute
            case "$elemMatch":
                return elemMatch(attributeValue: attribute, condition: conditionValue, savedGroups: savedGroups, visited: visited)
            // Evaluate SIE operator - whether condition size is same as that of attribute
            case "$size":
                return evalConditionValue(conditionValue: conditionValue, attributeValue: JSON(attribute.count), savedGroups: savedGroups, visited: visited)
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
    /// Each relation is evaluated directly, so a NaN operand fails all four, as in JavaScript.
    private func compareOrdered(operatorKey: String, attributeValue: JSON, conditionValue: JSON) -> Bool {
        guard isOrderable(attributeValue, conditionValue) else { return false }

        if attributeValue.type == .number {
            let attr = attributeValue.doubleValue
            let cond = conditionValue.doubleValue
            switch operatorKey {
            case "$lt": return attr < cond
            case "$lte": return attr <= cond
            case "$gt": return attr > cond
            default: return attr >= cond
            }
        }

        let attr = attributeValue.stringValue.utf16
        let cond = conditionValue.stringValue.utf16
        switch operatorKey {
        case "$lt": return attr.lexicographicallyPrecedes(cond)
        case "$lte": return !cond.lexicographicallyPrecedes(attr)
        case "$gt": return cond.lexicographicallyPrecedes(attr)
        default: return !attr.lexicographicallyPrecedes(cond)
        }
    }

    /// Tri-state `$all`/`$alli`, as JS `isInAll`: every expected value must match some element.
    /// An element that can't be decided leaves that value undecided unless another element matches.
    private func isInAll(actual: JSON, expected: [JSON], savedGroups: JSON?, insensitive: Bool, visited: Set<String>) -> Bool? {
        guard let actualArray = actual.array else { return false }
        var result: Bool? = true
        for expectedItem in expected {
            var passed: Bool? = false
            for actualItem in actualArray {
                let entry = evalConditionValue(conditionValue: expectedItem, attributeValue: actualItem, savedGroups: savedGroups, insensitive: insensitive, visited: visited)
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

    /// Equality for `$eq` and `$ne`, as JS `===`: scalars compare by value without coercion, and an
    /// array or object never equals one parsed separately, so it is never equal here.
    private func isIdentical(_ lhs: JSON, _ rhs: JSON) -> Bool {
        let isCollection: (JSON) -> Bool = { $0.type == .array || $0.type == .dictionary }
        if isCollection(lhs) || isCollection(rhs) { return false }
        return isStrictlyEqual(lhs, rhs)
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

    /// Resolves a `$savedGroup` reference: is the user a member of the group it names?
    ///
    /// Unlike `$inGroup`, this is a top-level operator with no attribute of its own, so the entry
    /// decides what membership means — a list entry names the attribute to test, and a condition
    /// entry is evaluated in full.
    ///
    /// Anything this SDK cannot make sense of matches nobody rather than throwing, and a group type
    /// added after this SDK was built is undecided (`nil`), so it fails under `$not` too.
    ///
    /// `visited` holds the ids currently being resolved, so a group that references itself —
    /// directly or along a chain — stops instead of recursing forever.
    ///
    /// Lookups go through `JSON`'s key subscript rather than `.dictionary`, which copies the whole
    /// object it is read from.
    private func evalSavedGroup(attributes: JSON, reference: JSON, savedGroups: JSON?, visited: Set<String>) -> Bool? {
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
            return evalCondition(attributes: attributes, conditionObj: condition, savedGroups: savedGroups, visited: visited.union([id]))

        // A group type added after this SDK was built
        default:
            return nil
        }
    }

    /// The values `$inGroup` / `$notInGroup` compare against, or `nil` when the entry carries none
    /// and both operators must therefore fail closed.
    ///
    /// A `savedGroups` entry is either the bare array these operators were built for, or a
    /// `savedGroupReferencesV2` typed entry. Only the list flavour of the latter has values to
    /// offer: a condition group is resolved through `$savedGroup`.
    ///
    /// The split between an absent id and an unreadable entry is deliberate. An unknown group id, a
    /// missing `savedGroups` object, and a group id that is not a string all resolve to an empty
    /// list, so membership is simply false and `$notInGroup` keeps passing. An entry that is present
    /// but cannot be read resolves to `nil` instead, which the call site turns into false for both
    /// operators. `exists()` is what separates an absent id from a present one, since the subscript
    /// answers with a null `JSON` either way and only marks the former with an error.
    private func savedGroupListValues(_ conditionValue: JSON, _ savedGroups: JSON?) -> [JSON]? {
        guard let groupId = conditionValue.string, let savedGroups else { return [] }

        let entry = savedGroups[groupId]
        guard entry.exists() else { return [] }

        if let array = entry.array { return array }
        if entry.type == .dictionary, entry["type"].string == "list" { return entry["values"].array }
        return nil
    }

    /// A saved group type added after this SDK was built: neither a bare array nor a `list` or
    /// `condition` entry. `$inGroup` / `$notInGroup` on one are undecided, as in the JS SDK.
    private func isNewGroupType(_ conditionValue: JSON, _ savedGroups: JSON?) -> Bool {
        guard let groupId = conditionValue.string, let savedGroups else { return false }
        let entry = savedGroups[groupId]
        guard entry.type == .dictionary else { return false }
        let type = entry["type"].string
        return type != "list" && type != "condition"
    }

    /// JS truthiness: `false`, `0`, `NaN`, `""` and null are falsy; arrays and objects are truthy.
    private func isJsTruthy(_ value: JSON) -> Bool {
        switch value.type {
        case .bool: return value.boolValue
        case .number: return value.doubleValue != 0 && !value.doubleValue.isNaN
        case .string: return !value.stringValue.isEmpty
        case .array, .dictionary: return true
        default: return false
        }
    }

    private func isPrimitive(value: JSON) -> Bool {
        
        if value.number != nil || value.string != nil || value.bool != nil || value.int != nil || value == .null {
            return true
        }
        return false
    }
    
}
