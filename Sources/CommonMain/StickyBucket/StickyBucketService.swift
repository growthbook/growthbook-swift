import Foundation

public protocol StickyBucketServiceProtocol {
    func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument?
    func saveAssignments(doc: StickyAssignmentsDocument)
    func getAllAssignments(attributes: [String: String]) -> [String: StickyAssignmentsDocument]
    func clearCache() throws
}

public protocol StickyBucketServiceWithFileCacheProtocol: StickyBucketCacheInterface {
    func updateCacheDirectoryURL(_ directoryURL: URL)
}

public class StickyBucketService: StickyBucketServiceProtocol {
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

    public func getAssignments(attributeName: String, attributeValue: String) -> StickyAssignmentsDocument? {
        let key = "\(attributeName)||\(attributeValue)"

        return try? cache?.stickyAssignment(for: prefix + key)
    }
    
    public func saveAssignments(doc: StickyAssignmentsDocument) {
        let key = "\(doc.attributeName)||\(doc.attributeValue)"

        try? cache?.updateStickyAssignment(doc, for: prefix + key)
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
        (cache as? StickyBucketFileStorageCacheInterface)?.updateCacheDirectoryURL(directoryURL)
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
