import XCTest
import SwiftyJSON
@testable import GrowthBook

class CachingManagerTest: XCTestCase {
    let manager = CachingManager()

    func testCachingFileName() throws {

        let fileName = "gb-features.txt"

        let filePath = manager.getTargetFile(fileName: fileName)

        XCTAssertTrue(filePath.hasPrefix("/Users"))
        XCTAssertTrue(filePath.hasSuffix(fileName))
    }

    func testCaching() throws {

        let fileName = "gb-features.txt"

        do {
            let data = try JSON("GrowthBook").rawData()
            manager.saveContent(fileName: fileName, content: data)

            if let fileContents = manager.getContent(fileName: fileName) {
                let json = try JSON(data: fileContents)
                XCTAssertTrue(json.stringValue == "GrowthBook")
            }
        } catch {
            logger.error("Failed get raw data or parse json error: \(error.localizedDescription)")
        }
    }

}
