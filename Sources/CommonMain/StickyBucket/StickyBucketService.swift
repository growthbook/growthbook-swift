import Foundation

public protocol StickyBucketServiceProtocol: Sendable {
    func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument?
    func saveAssignments(doc: StickyAssignmentsDocument)
    func getAllAssignments(attributes: [String: String]) -> [String: StickyAssignmentsDocument]
    func clearCache() throws
    func updateCacheDirectoryURL(_ directoryURL: URL)
}

public final class StickyBucketService: StickyBucketServiceProtocol {
    private let prefix: String
    let cache: StickyBucketCacheInterface?

    @available(*, deprecated, message: "Use init(prefix:cache:) instead")
    public init(prefix: String = "gbStickyBuckets__", localStorage: CachingLayer? = nil) {
        self.prefix = prefix
        self.cache = localStorage.map(CachingLayerWrapper.init(_:))
    }

    public init(prefix: String = "gbStickyBuckets__", cache: StickyBucketCacheInterface?) {
        self.prefix = prefix
        self.cache = cache
    }

    private func cacheKey(for attributeName: String, attributeValue: String) -> String {
        let hash = "\(attributeName)||\(attributeValue)".sha256HashString
        return "\(prefix)\(hash)"
    }

    public func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument? {
        let cacheKey = cacheKey(for: attributeName, attributeValue: attributeValue)

        return try? cache?.stickyAssignment(for: cacheKey)
    }
    
    public func saveAssignments(doc: StickyAssignmentsDocument) {
        let cacheKey = cacheKey(for: doc.attributeName, attributeValue: doc.attributeValue)
        // While we have multi-context SDK need to fetch assigned assignments and merge.
        // When there will be a singe-context SDK we can put merge logic to the User Context.

        var newDoc = doc

        if let previousDoc = try? cache?.stickyAssignment(for: cacheKey) {
            newDoc.assignments = previousDoc.assignments.merging(newDoc.assignments) { (_, new) in new }
        }

        try? cache?.updateStickyAssignment(newDoc, for: cacheKey)
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

    public func clearCache() throws {
        try cache?.clearCache()
    }
}

extension StickyBucketService {
    public func updateCacheDirectoryURL(_ directoryURL: URL) {
        if let cache = cache as? StickyBucketFileStorageCacheInterface {
            cache.updateCacheDirectoryURL(directoryURL)
        }
    }
}

private struct CachingLayerWrapper {
    private let cachingLayer: CachingLayer

    init(_ cachingLayer: CachingLayer) {
        self.cachingLayer = cachingLayer
    }
}

extension CachingLayerWrapper: StickyBucketCacheInterface {
    func stickyAssignment(for key: String) throws -> StickyAssignmentsDocument? {
        guard
            let data = cachingLayer.getContent(fileName: key),
            let jsonPetitions = try? JSONDecoder().decode(StickyAssignmentsDocument.self, from: data)
        else {
            return .none
        }
        return jsonPetitions
    }

    func updateStickyAssignment(_ value: StickyAssignmentsDocument?, for key: String) throws {
        guard let value, let docData = try? JSONEncoder().encode(value) else {
            return
        }

        cachingLayer.saveContent(fileName: key, content: docData)
    }

    func clearCache() {
        (cachingLayer as? CachingManager)?.clearCache()
    }
}

extension CachingLayerWrapper: StickyBucketFileStorageCacheInterface {
    func updateCacheDirectoryURL(_ directoryURL: URL) {
        CachingManager.shared.updateCacheDirectoryURL(directoryURL)
    }
}
