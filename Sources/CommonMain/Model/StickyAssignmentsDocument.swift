import Foundation

@objc public class StickyAssignmentsDocument: NSObject, Codable {
    var attributeName: String
    var attributeValue: String
    var assignments: [String: String]
    
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
