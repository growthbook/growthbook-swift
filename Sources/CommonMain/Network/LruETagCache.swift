import Foundation

/// Thread-safe LRU (Least Recently Used) cache for storing ETags.
///
/// This cache has a maximum capacity and automatically evicts the least recently
/// accessed entries when the capacity is exceeded. All operations are thread-safe.
class LruETagCache {
    private let maxSize: Int
    private var cache: [String: String] = [:]
    private var accessOrder: [String] = [] // Tracks access order for LRU
    private let lock = NSLock()
    
    /// Initialize the cache with a maximum size
    /// - Parameter maxSize: Maximum number of entries to store (default: 100)
    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }
    
    /// Retrieves the ETag for the given URL.
    /// - Parameter url: The URL key
    /// - Returns: The ETag value, or nil if not present
    func get(_ url: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        guard let value = cache[url] else {
            return nil
        }
        
        // Update access order (move to end = most recently used)
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(url)
        
        return value
    }
    
    /// Stores an ETag for the given URL.
    /// - Parameters:
    ///   - url: The URL key
    ///   - eTag: The ETag value to store (nil removes the entry)
    func put(_ url: String, _ eTag: String?) {
        lock.lock()
        defer { lock.unlock() }
        
        guard let eTag = eTag else {
            // Remove entry if eTag is nil
            cache.removeValue(forKey: url)
            if let index = accessOrder.firstIndex(of: url) {
                accessOrder.remove(at: index)
            }
            return
        }
        
        // Update or add entry
        let isNewEntry = cache[url] == nil
        cache[url] = eTag
        
        // Update access order
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
        accessOrder.append(url)
        
        // Evict oldest entry if capacity exceeded
        if isNewEntry && cache.count > maxSize {
            if let oldest = accessOrder.first {
                cache.removeValue(forKey: oldest)
                accessOrder.removeFirst()
            }
        }
    }
    
    /// Removes the ETag for the given URL.
    /// - Parameter url: The URL key
    /// - Returns: The removed ETag value, or nil if not present
    @discardableResult
    func remove(_ url: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        
        let value = cache.removeValue(forKey: url)
        if let index = accessOrder.firstIndex(of: url) {
            accessOrder.remove(at: index)
        }
        return value
    }
    
    /// Clears all entries from the cache.
    func clear() {
        lock.lock()
        defer { lock.unlock() }
        
        cache.removeAll()
        accessOrder.removeAll()
    }
    
    /// Returns the current number of entries in the cache.
    var size: Int {
        lock.lock()
        defer { lock.unlock() }
        return cache.count
    }
    
    /// Returns true if the cache contains an entry for the given URL.
    /// - Parameter url: The URL key
    /// - Returns: true if the cache contains the key
    func contains(_ url: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return cache.keys.contains(url)
    }
}
