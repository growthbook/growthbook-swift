import Foundation

/// In-memory implementation of `CachingLayer`.
///
/// Stores cached content in a dictionary instead of on disk. Useful for unit
/// tests and ephemeral sessions where persistence across app launches is not
/// wanted. Entries are namespaced by cache key to mirror `CachingManager`, so
/// switching keys isolates content, and `clearCache()` only removes entries for
/// the current key. Access is synchronized for thread safety.
///
/// Filesystem-oriented configuration (`setSystemCacheDirectory` /
/// `setCustomCachePath`) is intentionally a no-op — an in-memory cache has no
/// directory.
@objc public class InMemoryCache: NSObject, CachingLayer {

    private var storage: [String: Data] = [:]
    private var cacheKey: String = ""

    private let lock = NSLock()

    public override init() {
        super.init()
    }

    public func setCacheKey(_ key: String) {
        lock.withLock {
            self.cacheKey = key
        }
    }

    /// No-op: an in-memory cache has no filesystem directory.
    @objc public func setSystemCacheDirectory(_ directory: CacheDirectory) {}

    /// No-op: an in-memory cache has no filesystem path.
    @objc public func setCustomCachePath(_ path: String) {}

    /// Save content in memory
    @objc public func saveContent(fileName: String, content: Data) {
        lock.withLock {
            storage[namespacedKey(for: fileName)] = content
        }
    }

    /// Get content from memory
    @objc public func getContent(fileName: String) -> Data? {
        lock.withLock {
            storage[namespacedKey(for: fileName)]
        }
    }

    /// Remove all entries stored under the current cache key.
    @objc public func clearCache() {
        lock.withLock {
            let prefix = "\(cacheKey)/"
            storage = storage.filter { !$0.key.hasPrefix(prefix) }
        }
    }

    /// Build the storage key, mirroring `CachingManager`: entries are namespaced
    /// by cache key and the optional `.txt` suffix is stripped so that
    /// `"Foo"` and `"Foo.txt"` resolve to the same entry.
    private func namespacedKey(for fileName: String) -> String {
        let file = fileName.replacingOccurrences(of: ".txt", with: "")
        return "\(cacheKey)/\(file)"
    }
}
