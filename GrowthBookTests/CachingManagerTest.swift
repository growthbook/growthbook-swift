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
    
    override func tearDown() {
           manager.clearCache()
           super.tearDown()
       }
}
