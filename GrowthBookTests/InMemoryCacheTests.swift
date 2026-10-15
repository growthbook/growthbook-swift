import XCTest

@testable import GrowthBook

class InMemoryCacheTests: XCTestCase {

    private func data(_ value: String) -> Data {
        Data(value.utf8)
    }

    func testSaveAndGet() {
        let cache = InMemoryCache()
        cache.saveContent(fileName: "FeatureCache", content: data("payload"))
        XCTAssertEqual(cache.getContent(fileName: "FeatureCache"), data("payload"))
    }

    func testGetMissingReturnsNil() {
        let cache = InMemoryCache()
        XCTAssertNil(cache.getContent(fileName: "missing"))
    }

    func testOverwrite() {
        let cache = InMemoryCache()
        cache.saveContent(fileName: "key", content: data("first"))
        cache.saveContent(fileName: "key", content: data("second"))
        XCTAssertEqual(cache.getContent(fileName: "key"), data("second"))
    }

    func testTxtSuffixIsNormalized() {
        let cache = InMemoryCache()
        cache.saveContent(fileName: "Foo.txt", content: data("payload"))
        // Mirrors CachingManager: ".txt" is stripped, so both names resolve to one entry.
        XCTAssertEqual(cache.getContent(fileName: "Foo"), data("payload"))
        XCTAssertEqual(cache.getContent(fileName: "Foo.txt"), data("payload"))
    }

    func testClearCacheRemovesCurrentKeyEntries() {
        let cache = InMemoryCache()
        cache.saveContent(fileName: "FeatureCache", content: data("payload"))
        cache.clearCache()
        XCTAssertNil(cache.getContent(fileName: "FeatureCache"))
    }

    func testCacheKeyNamespacesEntries() {
        let cache = InMemoryCache()
        cache.setCacheKey("key-a")
        cache.saveContent(fileName: "FeatureCache", content: data("a"))

        cache.setCacheKey("key-b")
        // Different key => isolated namespace, no leakage from key-a.
        XCTAssertNil(cache.getContent(fileName: "FeatureCache"))

        cache.saveContent(fileName: "FeatureCache", content: data("b"))
        XCTAssertEqual(cache.getContent(fileName: "FeatureCache"), data("b"))

        cache.setCacheKey("key-a")
        XCTAssertEqual(cache.getContent(fileName: "FeatureCache"), data("a"))
    }

    func testClearCacheOnlyClearsCurrentKey() {
        let cache = InMemoryCache()
        cache.setCacheKey("key-a")
        cache.saveContent(fileName: "FeatureCache", content: data("a"))

        cache.setCacheKey("key-b")
        cache.saveContent(fileName: "FeatureCache", content: data("b"))
        cache.clearCache()

        // key-b cleared...
        XCTAssertNil(cache.getContent(fileName: "FeatureCache"))
        // ...but key-a is untouched.
        cache.setCacheKey("key-a")
        XCTAssertEqual(cache.getContent(fileName: "FeatureCache"), data("a"))
    }

    func testConformsToCachingLayer() {
        // Drop-in replacement: usable anywhere a CachingLayer is expected.
        let cache: CachingLayer = InMemoryCache()
        cache.setSystemCacheDirectory(.caches) // no-op, must not crash
        cache.setCustomCachePath("/tmp/ignored") // no-op, must not crash
        cache.saveContent(fileName: "k", content: data("v"))
        XCTAssertEqual(cache.getContent(fileName: "k"), data("v"))
    }

    func testConcurrentAccessIsSafe() {
        let cache = InMemoryCache()
        let iterations = 1_000
        DispatchQueue.concurrentPerform(iterations: iterations) { i in
            let name = "file-\(i % 16)"
            cache.saveContent(fileName: name, content: data("\(i)"))
            _ = cache.getContent(fileName: name)
        }
        // No assertion on values (interleaving is nondeterministic); the test
        // passes if it completes without a crash under the thread sanitizer.
        XCTAssertNotNil(cache.getContent(fileName: "file-0"))
    }
}
