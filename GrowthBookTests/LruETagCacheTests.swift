import XCTest
@testable import GrowthBook

class LruETagCacheTests: XCTestCase {
    var cache: LruETagCache!
    
    override func setUp() {
        super.setUp()
        cache = LruETagCache(maxSize: 3)
    }
    
    override func tearDown() {
        cache = nil
        super.tearDown()
    }
    
    // MARK: - Basic Operations
    
    func testBasicPutAndGetOperations() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        
        XCTAssertEqual("etag1", cache.get("url1"))
        XCTAssertEqual("etag2", cache.get("url2"))
        XCTAssertNil(cache.get("url3"))
    }
    
    func testLRUEvictionWhenCapacityExceeded() {
        // Add 3 items (fills capacity)
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        cache.put("url3", "etag3")
        
        // Add 4th item - should evict url1 (least recently used)
        cache.put("url4", "etag4")
        
        XCTAssertNil(cache.get("url1"))  // Evicted
        XCTAssertEqual("etag2", cache.get("url2"))
        XCTAssertEqual("etag3", cache.get("url3"))
        XCTAssertEqual("etag4", cache.get("url4"))
        XCTAssertEqual(3, cache.size)
    }
    
    func testAccessingAnEntryUpdatesItsPositionInLRU() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        cache.put("url3", "etag3")
        
        // Access url1 to make it most recently used
        _ = cache.get("url1")
        
        // Add url4 - should evict url2 (now least recently used)
        cache.put("url4", "etag4")
        
        XCTAssertEqual("etag1", cache.get("url1"))  // Still present
        XCTAssertNil(cache.get("url2"))  // Evicted
        XCTAssertEqual("etag3", cache.get("url3"))
        XCTAssertEqual("etag4", cache.get("url4"))
    }
    
    func testNullValueRemovesEntry() {
        cache.put("url1", "etag1")
        XCTAssertEqual("etag1", cache.get("url1"))
        
        cache.put("url1", nil)
        XCTAssertNil(cache.get("url1"))
        XCTAssertEqual(0, cache.size)
    }
    
    func testRemoveOperation() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        
        let removed = cache.remove("url1")
        
        XCTAssertEqual("etag1", removed)
        XCTAssertNil(cache.get("url1"))
        XCTAssertEqual(1, cache.size)
    }
    
    func testClearOperation() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        cache.put("url3", "etag3")
        
        cache.clear()
        
        XCTAssertEqual(0, cache.size)
        XCTAssertNil(cache.get("url1"))
        XCTAssertNil(cache.get("url2"))
        XCTAssertNil(cache.get("url3"))
    }
    
    func testContainsOperation() {
        cache.put("url1", "etag1")
        
        XCTAssertTrue(cache.contains("url1"))
        XCTAssertFalse(cache.contains("url2"))
    }
    
    // MARK: - Concurrency Tests
    
    func testConcurrentReadsAndWrites() {
        let largeCache = LruETagCache(maxSize: 100)
        let expectation = self.expectation(description: "Concurrent operations")
        expectation.expectedFulfillmentCount = 100
        
        let queue = DispatchQueue(label: "test.concurrent", attributes: .concurrent)
        
        // Launch 100 concurrent operations
        for i in 0..<100 {
            queue.async {
                switch i % 3 {
                case 0:
                    largeCache.put("url\(i)", "etag\(i)")
                case 1:
                    _ = largeCache.get("url\(i - 1)")
                case 2:
                    _ = largeCache.contains("url\(i - 2)")
                default:
                    break
                }
                expectation.fulfill()
            }
        }
        
        waitForExpectations(timeout: 5.0)
        
        // Verify cache is still operational and size is within bounds
        XCTAssertTrue(largeCache.size <= 100)
    }
    
    func testThreadSafetyWithRapidConcurrentAccess() {
        let threadSafeCache = LruETagCache(maxSize: 10)
        let expectation = self.expectation(description: "Thread safety")
        expectation.expectedFulfillmentCount = 20
        
        let queue = DispatchQueue(label: "test.threadsafe", attributes: .concurrent)
        let errorQueue = DispatchQueue(label: "test.errors")
        var errors: [Error] = []
        
        // Create 20 threads that rapidly access the cache
        for threadId in 0..<20 {
            queue.async {
                do {
                    for i in 0..<100 {
                        let key = "url\(i % 5)"
                        threadSafeCache.put(key, "etag\(threadId)-\(i)")
                        _ = threadSafeCache.get(key)
                        _ = threadSafeCache.contains(key)
                    }
                    expectation.fulfill()
                } catch {
                    errorQueue.sync {
                        errors.append(error)
                    }
                    expectation.fulfill()
                }
            }
        }
        
        waitForExpectations(timeout: 5.0)
        
        // Verify no exceptions occurred
        if !errors.isEmpty {
            XCTFail("Thread safety test failed with \(errors.count) errors: \(errors.first!.localizedDescription)")
        }
        
        // Verify cache is still within size bounds
        XCTAssertTrue(threadSafeCache.size <= 10)
    }
    
    // MARK: - Large Cache Operations
    
    func testLargeCacheOperations() {
        let largeCache = LruETagCache(maxSize: 100)
        
        // Add 150 items
        for i in 0..<150 {
            largeCache.put("url\(i)", "etag\(i)")
        }
        
        // Should only have 100 items (the most recent ones)
        XCTAssertEqual(100, largeCache.size)
        
        // First 50 should be evicted
        for i in 0..<50 {
            XCTAssertNil(largeCache.get("url\(i)"))
        }
        
        // Last 100 should be present
        for i in 50..<150 {
            XCTAssertEqual("etag\(i)", largeCache.get("url\(i)"))
        }
    }
    
    func testUpdatingExistingEntryDoesNotGrowCache() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        XCTAssertEqual(2, cache.size)
        
        // Update existing entry
        cache.put("url1", "etag1-updated")
        
        // Size should still be 2
        XCTAssertEqual(2, cache.size)
        XCTAssertEqual("etag1-updated", cache.get("url1"))
    }
    
    // MARK: - Edge Cases
    
    func testRemoveNonExistentEntry() {
        let removed = cache.remove("nonexistent")
        XCTAssertNil(removed)
    }
    
    func testGetAfterClear() {
        cache.put("url1", "etag1")
        cache.clear()
        XCTAssertNil(cache.get("url1"))
    }
    
    func testPutWithEmptyString() {
        cache.put("url1", "")
        XCTAssertEqual("", cache.get("url1"))
        XCTAssertTrue(cache.contains("url1"))
    }
    
    func testMultipleUpdatesToSameKey() {
        cache.put("url1", "etag1")
        cache.put("url1", "etag2")
        cache.put("url1", "etag3")
        
        XCTAssertEqual("etag3", cache.get("url1"))
        XCTAssertEqual(1, cache.size)
    }
    
    func testEvictionOrderAfterMixedOperations() {
        cache.put("url1", "etag1")
        cache.put("url2", "etag2")
        cache.put("url3", "etag3")
        
        // Access url1 and url2
        _ = cache.get("url1")
        _ = cache.get("url2")
        
        // Add url4 - should evict url3 (least recently accessed)
        cache.put("url4", "etag4")
        
        XCTAssertEqual("etag1", cache.get("url1"))
        XCTAssertEqual("etag2", cache.get("url2"))
        XCTAssertNil(cache.get("url3"))  // Evicted
        XCTAssertEqual("etag4", cache.get("url4"))
    }
}
