import XCTest

@testable import GrowthBook

class CachingManagerTest: XCTestCase {
    let manager = CachingManager(apiKey: "caching-test-api-key")

    func testCachingFileName() throws {

        let fileName = "gb-features.txt"

        let filePath = manager.getTargetFile(fileName: fileName)

        XCTAssertTrue(filePath.hasPrefix("/Users"))
        XCTAssertTrue(filePath.hasSuffix(fileName))
    }

    func testCaching() throws {

        let fileName = "gb-features.txt"

        do {
            let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
            manager.saveContent(fileName: fileName, content: data)

            if let fileContents = manager.getContent(fileName: fileName) {
                let json = try JSON(data: fileContents)
                XCTAssertTrue(json.dictionary == ["GrowthBook": "GrowthBook"])
            } else {
                XCTFail()
                logger.error("Failed get content")
            }
        } catch {
            XCTFail()
            logger.error("Failed get raw data or parse json error: \(error.localizedDescription)")
        }
    }

    func testClearCache() throws {
        
        let fileName = "gb-features.txt"

        do {
            let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
            manager.saveContent(fileName: fileName, content: data)

            manager.clearCache()
            
            XCTAssertTrue(manager.getContent(fileName: fileName) == nil)
        } catch {
            XCTFail()
            logger.error("Failed get raw data or parse json error: \(error.localizedDescription)")
        }
    }
    
    func testRemoveContentRemovesOnlyOneFile() throws {
        let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
        manager.saveContent(fileName: "gb-features.txt", content: data)
        manager.saveContent(fileName: "gb-other.txt", content: data)

        manager.removeContent(fileName: "gb-features.txt")

        XCTAssertNil(manager.getContent(fileName: "gb-features.txt"))
        XCTAssertNotNil(manager.getContent(fileName: "gb-other.txt"))
    }

    func testRemoveContentForMissingFileDoesNothing() {
        manager.removeContent(fileName: "never-written.txt")

        XCTAssertNil(manager.getContent(fileName: "never-written.txt"))
    }

    func testRemoveContentsWithPrefixRemovesMatchingFilesOnly() throws {
        let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
        manager.saveContent(fileName: "gbStickyBuckets__id||user-1.txt", content: data)
        manager.saveContent(fileName: "gbStickyBuckets__id||user-2.txt", content: data)
        manager.saveContent(fileName: "gb-features.txt", content: data)

        manager.removeContents(withPrefix: "gbStickyBuckets__")

        XCTAssertNil(manager.getContent(fileName: "gbStickyBuckets__id||user-1.txt"))
        XCTAssertNil(manager.getContent(fileName: "gbStickyBuckets__id||user-2.txt"))
        XCTAssertNotNil(manager.getContent(fileName: "gb-features.txt"), "features cache must survive a sticky-only purge")
    }

    override func tearDown() {
           manager.clearCache()
           super.tearDown()
       }
}
