import XCTest

@testable import GrowthBook

class GrowthBookSDKBuilderTests: XCTestCase {
    let testURL = "https://host.com/api/features/4r23r324f23"
    let testAttributes: JSON = JSON()

    func testSDKInitializationDefault() throws {
        let sdkInstance = GrowthBookBuilder(hostURL: testURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in }).initializer()
        
        XCTAssertTrue(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testURL)
        XCTAssertFalse(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKInitializationOverride() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(hostURL: testURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in })
            .setEnabled(isEnabled: false)
            .setForcedVariations(forcedVariations: variations)
            .setQAMode(isEnabled: true)
            .initializer()

        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().forcedVariations == JSON(variations))
        
    }
    
    func testSDKInitializationData() throws {
        
        let variations: [String: Int] = [:]

        let sdkInstance = GrowthBookBuilder(hostURL: testURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in })
            .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
            .setEnabled(isEnabled: false)
            .setForcedVariations(forcedVariations: variations)
            .setQAMode(isEnabled: true)
            .initializer()

        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().hostURL == testURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        
    }
    
    func testSDKFeaturesData() throws {
        let sdkInstance = GrowthBookBuilder(hostURL: testURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in })
            .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
            .initializer()
        
        XCTAssertTrue(sdkInstance.getFeatures().contains(where: {$0.key == "onboarding"}))
        XCTAssertFalse(sdkInstance.getFeatures().contains(where: {$0.key == "fwrfewrfe"}))
    }
    
    func testSDKRunMethods() throws {
        let sdkInstance = GrowthBookBuilder(hostURL: testURL,
                                        attributes: testAttributes,
                                        trackingCallback: { _, _ in })
            .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        let featureValue = sdkInstance.evalFeature(id: "fwrfewrfe")
        XCTAssertTrue(featureValue.source == FeatureSource.unknownFeature.rawValue)
        
        let expValue = sdkInstance.run(experiment: Experiment(key: "fwewrwefw"))
        XCTAssertTrue(expValue.variationId == 0)
    }
}
