import Foundation

@objc public protocol StickyBucketServiceProtocol {
    func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument?
    func saveAssignments(doc: StickyAssignmentsDocument)
    func getAllAssignments(attributes: [String: String]) -> [String: StickyAssignmentsDocument]
}

@objc public class StickyBucketService: NSObject, StickyBucketServiceProtocol {
    private let prefix: String
    private let localStorage = CachingManager()
    
    public init(prefix: String = "gbStickyBuckets__", localStoragePath: CacheDirectory = .applicationSupport) {
        self.prefix = prefix
        localStorage.setSystemCacheDirectory(localStoragePath)
    }
    
    public func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument? {
        let key = "\(attributeName)||\(attributeValue)"
                        
        if let data = localStorage.getContent(fileName: prefix + key), let jsonPetitions = try? JSONDecoder().decode(StickyAssignmentsDocument.self, from: data) {
            return jsonPetitions
        }

        return nil
    }
    
    public func saveAssignments(doc: StickyAssignmentsDocument) {
        let key = "\(doc.attributeName)||\(doc.attributeValue)"
        
        guard let docData = try? JSONEncoder().encode(doc) else { return }

        localStorage.saveContent(fileName: prefix + key, content: docData)
    }
    
    public func getAllAssignments(attributes: [String : String]) -> [String : StickyAssignmentsDocument] {
        var docs = [String : StickyAssignmentsDocument]()
        
        attributes.forEach { key, value in
            if let doc = getAssignments(attributeName: key, attributeValue: value) {
                let key = "\(doc.attributeName)||\(doc.attributeValue)"
                
                docs[key] = doc
            }
        }
        
        return docs
    }
}
