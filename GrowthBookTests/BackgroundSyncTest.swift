//
//  BackgroundSyncTest.swift
//  GrowthBookTests
//
//  Created by admin on 2/22/24.
//

import XCTest

@testable import GrowthBook

final class BackgroundSyncTest: XCTestCase {

    var event: [JSON]?
    
    override func setUp() {
        event = TestHelper().getServerSideEvent()
    }
    
    func testBackgroundSync() throws {
        let url = URL(fileURLWithPath: "/Users/admin/growthbook-swift-internal/GrowthBookTests/Source/json.json")
        let streamingUpdate = SSEHandler(url: url)
        streamingUpdate.addEventListener(event: "features") { id, event, data in }
        XCTAssertTrue(streamingUpdate.events().first == "features")
    }
}
