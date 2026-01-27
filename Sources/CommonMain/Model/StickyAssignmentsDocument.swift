import Foundation

@objc public class StickyAssignmentsDocument: NSObject, Codable {
    public let attributeName: String
    public let attributeValue: String
    public let assignments: [String: String]
    
    public init(attributeName: String, attributeValue: String, assignments: [String : String]) {
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        self.assignments = assignments
    }
    
    public init(attributeName: String, attributeValue: String, assignments: [String : JSON]) {
        self.attributeName = attributeName
        self.attributeValue = attributeValue
        
        var assignmentsDict: [String: String] = [:]
        assignments.forEach { (key, value) in
            assignmentsDict[key] = value.stringValue
        }
        
        self.assignments = assignmentsDict
    }
}
