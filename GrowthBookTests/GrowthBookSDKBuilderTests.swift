import XCTest

@testable import GrowthBook

class GrowthBookSDKBuilderTests: XCTestCase {
    let testApiHost = "https://host.com"
    let testClientKey = "4r23r324f23"
    let expectedURL = "https://host.com/api/features/4r23r324f23"
    let testAttributes: JSON = JSON()
    let testKeyString = "Ns04T5n9+59rl2x3SlNHtQ=="
    
    let cachingManager = CachingManager(apiKey: "4r23r324f23")
    
    final class RefreshFlag: @unchecked Sendable {
        private let lock = NSLock()
        private var _isRefreshed = false
        
        var isRefreshed: Bool {
            get {
                lock.lock()
                defer { lock.unlock() }
                return _isRefreshed
            }
            set {
                lock.lock()
                defer { lock.unlock() }
                _isRefreshed = newValue
            }
        }
        
        func reset() {
            isRefreshed = false
        }
    }
    
    func testSDKInitializationDefault() throws {
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            encryptionKey: testKeyString,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil, 
                                            backgroundSync: false).initializer()
        
        XCTAssertTrue(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().getFeaturesURL() == expectedURL)
        XCTAssertTrue(sdkInstance.getGBContext().encryptionKey == testKeyString)
        XCTAssertFalse(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationOverride() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil, backgroundSync: false).setRefreshHandler(refreshHandler: { _ in }).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().getFeaturesURL() == expectedURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().forcedVariations == JSON(variations))
        
    }
    
    func testSDKInitializationData() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().getFeaturesURL() == expectedURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationDataWithEncripted() throws {
        
        let variations: [String: Int] = [:]
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            encryptionKey: "3tfeoyW0wlo47bDnbWDkxg==",
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil, 
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().getFeaturesURL() == expectedURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        if !sdkInstance.getGBContext().features.isEmpty {
            XCTAssertTrue(sdkInstance.getGBContext().features.contains(where: { $0.key == "pricing-test-new"}))
        }
    }
    
    func testSDKRefreshHandler() throws {
        let refreshFlag = RefreshFlag()
        let expectation = XCTestExpectation(description: "First refresh handler")
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false,
                                            ttlSeconds:0).setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async {
                refreshFlag.isRefreshed = true
                expectation.fulfill()
            }
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(refreshFlag.isRefreshed)
        
        refreshFlag.reset()
        
        let refreshExpectation = XCTestExpectation(description: "Second refresh handler")
        
        sdkInstance.refreshHandler = { _ in
            DispatchQueue.main.async {
                refreshFlag.isRefreshed = true
                refreshExpectation.fulfill()
            }
        }
        
        sdkInstance.refreshCache()
        
        wait(for: [refreshExpectation], timeout: 1.0)
        XCTAssertTrue(refreshFlag.isRefreshed)
    }
    
    func testSDKFeaturesData() throws {
        let refreshFlag = RefreshFlag()
        let expectation = XCTestExpectation(description: "Features loaded")

        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async {
                refreshFlag.isRefreshed = true
                expectation.fulfill()
            }
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        wait(for: [expectation], timeout: 1.0)
        XCTAssertTrue(refreshFlag.isRefreshed)
        
        XCTAssertTrue(sdkInstance.getFeatures().contains(where: {$0.key == "onboarding"}))
        XCTAssertFalse(sdkInstance.getFeatures().contains(where: {$0.key == "fwrfewrfe"}))
            
    }
    
    func testSDKRunMethods() throws {
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil, 
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in
            
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        let featureValue = sdkInstance.evalFeature(id: "fwrfewrfe")
        XCTAssertTrue(featureValue.source == FeatureSource.unknownFeature.rawValue)
        
        let expValue = sdkInstance.run(experiment: Experiment(key: "fwewrwefw"))
        XCTAssertTrue(expValue.variationId == 0)
    }
    
    func testEncrypt() throws {
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false).initializer()
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
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil, 
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in

        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
            .setSystemCacheDirectory(.applicationSupport)
            .initializer()
        
        let fileName = "gb-features.txt"

        do {
            let data = try JSON(["GrowthBook": "GrowthBook"]).rawData()
            cachingManager.saveContent(fileName: fileName, content: data)

            sdkInstance.clearCache()

            XCTAssertTrue(cachingManager.getContent(fileName: fileName) == nil)
        } catch {
            XCTFail()
            logger.error("Failed get raw data or parse json error: \(error.localizedDescription)")
        }
    }
    
    func testTrackingCallback() throws {
        let attributes = JSON(["id": 1234])
        var countTrackingCallback = 0
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: attributes,
                                            trackingCallback: { experiment, experimentResult in
            countTrackingCallback += 1
        },
                                            refreshHandler: nil,
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        let _ = sdkInstance.evalFeature(id: "qrscanpayment1")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment1")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment2")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment2")
        
        XCTAssertEqual(2, countTrackingCallback)
    }
}
