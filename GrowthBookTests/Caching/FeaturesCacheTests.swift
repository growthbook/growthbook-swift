//
//  FeaturesCacheTests.swift
//  GrowthBook-IOS
//
//  Created by Vitalii Budnik on 1/24/25.
//

import Foundation
import XCTest

@testable import GrowthBook


class FeaturesCacheTests: XCTestCase {
    func testGetFeatures() throws {
        let storage = DataStorageInterfaceMock<Features>()
        let featureKey: String = "key"
        let featureRawValue: Bool = true
        let featureJSON: JSON = .init(featureRawValue)
        let feature: Feature = .init(json: ["defaultValue": featureJSON])
        let features: Features = [featureKey: feature]
        storage.underlyingValue = .init(features)

        let sut = FeaturesCache(storage: storage)

        XCTAssertEqual(try sut.features(), features)
        XCTAssertTrue(storage.didCallValue)
    }

    func testSetFeatures() throws {
        let storage = DataStorageInterfaceMock<Features>()

        let featureKey: String = "key"
        let featureRawValue: Bool = true
        let featureJSON: JSON = .init(featureRawValue)
        let feature: Feature = .init(json: ["defaultValue": featureJSON])
        let features: Features = [featureKey: feature]

        let sut = FeaturesCache(storage: storage)

        try sut.updateFeatures(features)

        XCTAssertTrue(storage.didCallUpdateValue)
        XCTAssertEqual(storage.updateValueCalls, [features])
        try XCTAssertEqual(sut.features(), features)
    }

    func testSetEncodedFeaturesRawData() throws {
        let storage = DataStorageInterfaceMock<Features>()

        let featureKey: String = "key"
        let featureDefaultRawValue: Bool = true
        let featureJSON: JSON = .init(featureDefaultRawValue)
        let feature: Feature = .init(json: ["defaultValue": featureJSON])
        let features: Features = [featureKey: feature]
        let encodedFeaturesData = try JSONEncoder().encode(features)

        let sut = FeaturesCache(storage: storage)

        try sut.setEncodedFeaturesRawData(encodedFeaturesData)

        XCTAssertTrue(storage.didCallSetRawData)
        XCTAssertEqual(storage.setRawDataCalls, [encodedFeaturesData])
        try XCTAssertEqual(sut.features()?[featureKey]?.defaultValue?.boolValue, featureDefaultRawValue)
    }

    func testClearCache() throws {
        let storage = DataStorageInterfaceMock<Features>()
        let featureKey: String = "key"
        let featureRawValue: Bool = true
        let featureJSON: JSON = .init(featureRawValue)
        let feature: Feature = .init(json: ["defaultValue": featureJSON])
        let features: Features = [featureKey: feature]
        storage.underlyingValue = .init(features)

        let sut = FeaturesCache(storage: storage)
        try XCTAssertNotNil(sut.features())

        try sut.clearCache()

        try XCTAssertNil(sut.features())
        XCTAssertTrue(storage.didCallReset)
    }
}
