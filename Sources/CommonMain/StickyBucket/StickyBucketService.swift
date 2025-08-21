import Foundation

@objc public protocol StickyBucketServiceProtocol {
    func getAssignments(attributeName: String, attributeValue: String, completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void)
    func saveAssignments(doc: StickyAssignmentsDocument, completion: @escaping (Error?) -> Void)
    func getAllAssignments(attributes: [String: String], completion: @escaping ([String: StickyAssignmentsDocument]?, Error?) -> Void)
}

@objc public class StickyBucketService: NSObject, StickyBucketServiceProtocol {
    private let prefix: String
    private let localStorage: CachingLayer?
    
    public init(prefix: String = "gbStickyBuckets__", localStorage: CachingLayer? = nil) {
        self.prefix = prefix
        self.localStorage = localStorage
    }
    
    public func getAssignments(attributeName: String,
                               attributeValue: String,
                               completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void) {
        let key = "\(attributeName)||\(attributeValue)"
        
        guard let localStorage = localStorage else {
            completion(nil, nil)
            return
        }
        
        if
            let data = localStorage.getContent(fileName: prefix + key),
            let jsonPetitions = try? JSONDecoder().decode(StickyAssignmentsDocument.self, from: data) {
            completion(jsonPetitions, nil)
            return
        }

        completion(nil, nil)
    }
    
    public func saveAssignments(doc: StickyAssignmentsDocument,
                                completion: @escaping (Error?) -> Void) {
        let key = "\(doc.attributeName)||\(doc.attributeValue)"
        
        guard let localStorage = localStorage,
              let docData = try? JSONEncoder().encode(doc) else {
            completion(nil)
            return
        }

        localStorage.saveContent(fileName: prefix + key, content: docData)
        completion(nil)
    }
    
    public func getAllAssignments(attributes: [String : String],
                                  completion: @escaping ([String : StickyAssignmentsDocument]?, Error?) -> Void) {
        var docs = [String : StickyAssignmentsDocument]()
        
        attributes.forEach { key, value in
            if let doc = getAssignmentsSync(attributeName: key, attributeValue: value) {
                let key = "\(doc.attributeName)||\(doc.attributeValue)"
                docs[key] = doc
            }
        }
        
        completion(docs, nil)
    }
    
    private func getAssignmentsSync(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument? {
        let key = "\(attributeName)||\(attributeValue)"
        
        guard let localStorage = localStorage else { return nil }
                
        if
            let data = localStorage.getContent(fileName: prefix + key),
            let jsonPetitions = try? JSONDecoder().decode(StickyAssignmentsDocument.self, from: data) {
            return jsonPetitions
        }

        return nil
    }
}
