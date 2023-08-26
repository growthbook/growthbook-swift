import XCTest

@testable import GrowthBook

class GrowthBookSDKBuilderTests: XCTestCase {
    let testURL = "https://host.com/api/features/4r23r324f23"
    let testAttributes: JSON = JSON()
    let testKeyString = "Ns04T5n9+59rl2x3SlNHtQ=="
    
    func testSDKInitializationDefault() throws {
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            encryptionKey: testKeyString,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).initializer()
        
        XCTAssertTrue(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().url == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().encryptionKey == testKeyString)
        XCTAssertFalse(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationOverride() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in }).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().url == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().forcedVariations == JSON(variations))
        
    }
    
    func testSDKInitializationData() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().url == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationDataWithEncripted() throws {
        
        let variations: [String: Int] = [:]
        
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            encryptionKey: "3tfeoyW0wlo47bDnbWDkxg==",
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().url == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().features.contains(where: { $0.key == "pricing-test-new"}))
    }
    
    func testSDKRefreshHandler() throws {
        
        var isRefreshed = false
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in
            isRefreshed = true
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()

        XCTAssertTrue(isRefreshed)
        
        isRefreshed = false
        
        sdkInstance.refreshCache()
        
        XCTAssertTrue(isRefreshed)
        
    }
    
    func testSDKFeaturesData() throws {
        
        var isRefreshed = false

        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in
            isRefreshed = true
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        XCTAssertTrue(isRefreshed)
        
        XCTAssertTrue(sdkInstance.getFeatures().contains(where: {$0.key == "onboarding"}))
        XCTAssertFalse(sdkInstance.getFeatures().contains(where: {$0.key == "fwrfewrfe"}))
    }
    
    func testSDKRunMethods() throws {
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in
            
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        let featureValue = sdkInstance.evalFeature(id: "fwrfewrfe")
        XCTAssertTrue(featureValue.source == FeatureSource.unknownFeature.rawValue)
        
        let expValue = sdkInstance.run(experiment: Experiment(key: "fwewrwefw"))
        XCTAssertTrue(expValue.variationId == 0)
    }
    
    func testEncrypt() throws {
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).initializer()
        let decoder = JSONDecoder()
        let encryptedFeatures = "vMSg2Bj/IurObDsWVmvkUg==.L6qtQkIzKDoE2Dix6IAKDcVel8PHUnzJ7JjmLjFZFQDqidRIoCxKmvxvUj2kTuHFTQ3/NJ3D6XhxhXXv2+dsXpw5woQf0eAgqrcxHrbtFORs18tRXRZza7zqgzwvcznx"
        let expectedResult = "{\"testfeature1\":{\"defaultValue\":true,\"rules\":[{\"condition\":{\"id\":\"1234\"},\"force\":false}]}}"
        sdkInstance.setEncryptedFeatures(encryptedString: encryptedFeatures, encryptionKey: testKeyString)
        guard
            let dataExpectedResult = expectedResult.data(using: .utf8),
            let features = try? decoder.decode([String: Feature].self, from: dataExpectedResult)
        else {
            XCTFail()
            return
        }
        XCTAssertTrue(sdkInstance.gbContext.features["testfeature1"]?.rules?[0].condition == features["testfeature1"]?.rules?[0].condition)
        XCTAssertTrue(sdkInstance.gbContext.features["testfeature1"]?.rules?[0].force == features["testfeature1"]?.rules?[0].force)
    }
    
    func testClearCache() throws {
        
        let sdkInstance = GrowthBookBuilder(url: testURL,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in

        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
            .setCacheDirectory(.documents)
            .initializer()
        
        let fileName = "gb-features.txt"

        do {
            let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
            CachingManager.shared.saveContent(fileName: fileName, content: data)

            sdkInstance.clearCache()

            XCTAssertTrue(CachingManager.shared.getContent(fileName: fileName) == nil)
        } catch {
            XCTFail()
            logger.error("Failed get raw data or parse json error: \(error.localizedDescription)")
        }
    }
}
