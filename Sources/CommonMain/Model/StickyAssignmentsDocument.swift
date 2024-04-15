import Foundation

public struct StickyAssignmentsDocument: Codable {
    var attributeName: String
    var attributeValue: String
    var assignments: [String: String]
}
