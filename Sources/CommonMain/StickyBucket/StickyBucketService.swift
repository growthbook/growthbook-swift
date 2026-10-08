import Foundation

@objc public protocol StickyBucketServiceProtocol {
    func getAssignments(attributeName: String, attributeValue: String, completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void)
    func saveAssignments(doc: StickyAssignmentsDocument, completion: @escaping (Error?) -> Void)
    func getAllAssignments(attributes: [String: String], completion: @escaping ([String: StickyAssignmentsDocument]?, Error?) -> Void)

    /// Removes the stored document for a single `attributeName||attributeValue` pair.
    ///
    /// Optional: custom services written against earlier SDK versions keep compiling. When it is
    /// not implemented, `GrowthBookSDK.clearStickyBuckets(forAttribute:value:)` only drops the
    /// in-memory copy and logs a warning — the persisted document reappears on the next refresh.
    @objc optional func deleteAssignments(attributeName: String, attributeValue: String, completion: @escaping (Error?) -> Void)

    /// Removes every stored document owned by this service.
    ///
    /// Optional, with the same caveat as `deleteAssignments(attributeName:attributeValue:completion:)`.
    @objc optional func clearAllAssignments(completion: @escaping (Error?) -> Void)
}

@objc public class StickyBucketService: NSObject, StickyBucketServiceProtocol {
    private let prefix: String
    private let localStorage : CachingManager
    
    public init(prefix: String = "gbStickyBuckets__", localStoragePath: CacheDirectory = .applicationSupport, cacheKey: String? = nil) {
        self.prefix = prefix
        self.localStorage = CachingManager(apiKey: cacheKey)
        super.init()
        localStorage.setSystemCacheDirectory(localStoragePath)
    }
    
    public func getAssignments(attributeName: String,
                               attributeValue: String,
                               completion: @escaping (StickyAssignmentsDocument?, Error?) -> Void) {
        let key = "\(attributeName)||\(attributeValue)"
        
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
        
        
        guard let docData = try? JSONEncoder().encode(doc) else {
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
    
    public func deleteAssignments(attributeName: String,
                                  attributeValue: String,
                                  completion: @escaping (Error?) -> Void) {
        let key = "\(attributeName)||\(attributeValue)"

        localStorage.removeContent(fileName: prefix + key)
        completion(nil)
    }

    public func clearAllAssignments(completion: @escaping (Error?) -> Void) {
        localStorage.removeContents(withPrefix: prefix)
        completion(nil)
    }

    private func getAssignmentsSync(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument? {
        let key = "\(attributeName)||\(attributeValue)"
                        
        if let data = localStorage.getContent(fileName: prefix + key), let jsonPetitions = try? JSONDecoder().decode(StickyAssignmentsDocument.self, from: data) {
            return jsonPetitions
        }

        return nil
    }
}
