//
//  GrowthBookSDKCachingManagerTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/24/25.
//

import Foundation
import XCTest

@testable import GrowthBook

class GrowthBookSDKCachingManagerTests: XCTestCase {
    let directoryURL = URL(fileURLWithPath: NSTemporaryDirectory().appending("/test"))

    override func setUp() {
        super.setUp()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    override func tearDown() {
        super.tearDown()
        try? FileManager.default.removeItem(at: directoryURL)
    }

    func testClearCache() throws {
        let featuresCache: FeaturesCacheInterfaceMock = .init()
        let savedGroupsCache: SavedGroupsCacheInterfaceMock = .init()

        let sut = GrowthBookSDKCachingManager(featuresCache: featuresCache, savedGroupsCache: savedGroupsCache)

        try sut.clearCache()

        XCTAssertTrue(featuresCache.didCallClearCache)
        XCTAssertTrue(savedGroupsCache.didCallClearCache)
    }

    func testFileStorage() throws {
        let featuresCacheFilename = "features"
        let savedGroupsCacheFilename = "savedGroups"
        let fileManager: FileManager = .default

        let sut = GrowthBookSDKCachingManager.withFileStorage(directoryURL: directoryURL, featuresCacheFilename: featuresCacheFilename, savedGroupsCacheFilename: savedGroupsCacheFilename, fileManager: fileManager)

        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(featuresCacheFilename, isDirectory: false).path))
        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(savedGroupsCacheFilename, isDirectory: false).path))

        try sut.featuresCache.updateFeatures([:])
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(featuresCacheFilename, isDirectory: false).path))

        try sut.savedGroupsCache.updateSavedGroups(JSON(true))
        XCTAssertTrue(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(savedGroupsCacheFilename, isDirectory: false).path))

        try sut.clearCache()

        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(featuresCacheFilename, isDirectory: false).path))
        XCTAssertFalse(fileManager.fileExists(atPath: directoryURL.appendingPathComponent(savedGroupsCacheFilename, isDirectory: false).path))
    }
}
