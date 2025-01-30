import Foundation

public struct StickyAssignmentsDocument: Codable, Equatable, Sendable {
    public var attributeName: String
    public var attributeValue: String
    public var assignments: [String: String]
    
    init(attributeName: String, attributeValue: String, assignments: [String : String]) {
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        self.assignments = assignments
    }
    
    init(attributeName: String, attributeValue: String, assignments: [String : JSON]) {
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        
        var assignmentsDict: [String: String] = [:]
        assignments.forEach { (key, value) in
            assignmentsDict[key] = value.stringValue
        }
        
        self.assignments = assignmentsDict
    }
}
