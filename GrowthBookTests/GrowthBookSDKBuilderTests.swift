import XCTest

@testable import GrowthBook

class GrowthBookSDKBuilderTests: XCTestCase {
    let testApiKey = "4r23r324f23"
    let testHostURL = "https://host.com"
    let testAttributes: JSON = JSON()

    func testSDKInitializationDefault() throws {
        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in },
                                        refreshHandler: nil).initializer()
        
        XCTAssertTrue(sdkInstance.getGBContext().apiKey == testApiKey)
        XCTAssertTrue(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testHostURL)
        XCTAssertFalse(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationOverride() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in },
                                        refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in }).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()

        XCTAssertTrue(sdkInstance.getGBContext().apiKey == testApiKey)
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testHostURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().forcedVariations == JSON(variations))
        
    }
    
    func testSDKInitializationData() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in },
                                        refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()

        XCTAssertTrue(sdkInstance.getGBContext().apiKey == testApiKey)
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testHostURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKRefreshHandler() throws {
        
        var isRefreshed = false
        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
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

        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
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
        let sdkInstance = SDKBuilderApp(apiKey: testApiKey,
                                        hostURL: testHostURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in },
                                        refreshHandler: nil).setRefreshHandler(refreshHandler: { _ in

        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        let featureValue = sdkInstance.feature(id: "fwrfewrfe")
        XCTAssertTrue(featureValue.source == FeatureSource.unknownFeature.rawValue)
        
        let expValue = sdkInstance.run(experiment: Experiment(key: "fwewrwefw"))
        XCTAssertTrue(expValue.variationId == 0)
    }
}
