import XCTest

@testable import GrowthBook

class GrowthBookSDKBuilderTests: XCTestCase {
    let testApiHost = "https://host.com"
    let testStreamingHost = "https://streaming.host.com"
    let testClientKey = "4r23r324f23"
    let expectedURL = "https://host.com/api/features/4r23r324f23"
    let expectedStreamingHostURL = "https://streaming.host.com/sub/4r23r324f23"
    let expectedDefaultStreamingURL = "https://host.com/sub/4r23r324f23"
    let testAttributes: JSON = JSON()
    let testKeyString = "Ns04T5n9+59rl2x3SlNHtQ=="
    
    let cachingManager: CachingLayer = CachingManager(apiKey: "4r23r324f23")
    
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
    
    func testApiURL() throws {
        let gbContext = Context(apiHost: testApiHost,
                                streamingHost: testStreamingHost,
                                clientKey: testClientKey,
                                encryptionKey: nil,
                                isEnabled: true,
                                attributes: JSON(),
                                forcedVariations: JSON(),
                                isQaMode: false,
                                trackingClosure: { _, _ in },
                                backgroundSync: false,
                                savedGroups: JSON())
        
        let streamingHostURL = gbContext.getSSEUrl()
        
        gbContext.streamingHost = nil
        
        let defaultURL = gbContext.getSSEUrl()
        
        XCTAssertTrue(gbContext.getFeaturesURL() == expectedURL)
        XCTAssertTrue(streamingHostURL == expectedStreamingHostURL)
        XCTAssertTrue(defaultURL == expectedDefaultStreamingURL)
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
        let expectation = XCTestExpectation(description: "Features loaded")
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            encryptionKey: "3tfeoyW0wlo47bDnbWDkxg==",
                                            attributes: testAttributes,
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async {
                expectation.fulfill()
            }
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)).setEnabled(isEnabled: false).setForcedVariations(forcedVariations: variations).setQAMode(isEnabled: true).initializer()
        
        wait(for: [expectation], timeout: 1.0)
        
        XCTAssertFalse(sdkInstance.getGBContext().isEnabled)
        XCTAssertTrue(sdkInstance.getGBContext().getFeaturesURL() == expectedURL)
        XCTAssertTrue(sdkInstance.getGBContext().isQaMode)
        XCTAssertTrue(sdkInstance.getGBContext().attributes == testAttributes)
        XCTAssertTrue(sdkInstance.getGBContext().features.contains(where: { $0.key == "pricing-test-new"}))
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
        XCTAssertTrue(sdkInstance.getGBContext().features["testfeature1"]?.rules?[0].condition == features["testfeature1"]?.rules?[0].condition)
        XCTAssertTrue(sdkInstance.getGBContext().features["testfeature1"]?.rules?[0].force == features["testfeature1"]?.rules?[0].force)

        if let feature = sdkInstance.getGBContext().features["testfeature1"] {
            XCTAssertTrue(feature.rules?[0].condition == feature.rules?[0].condition)
            XCTAssertTrue(feature.rules?[0].force == feature.rules?[0].force)
        } else {
            XCTFail()
        }
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
        let expectation = XCTestExpectation(description: "Features loaded")
        
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: attributes,
                                            trackingCallback: { experiment, experimentResult in
            countTrackingCallback += 1
        },
                                            refreshHandler: nil,
                                            backgroundSync: false).setRefreshHandler(refreshHandler: { _ in
            expectation.fulfill()
        }).setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)).initializer()
        
        wait(for: [expectation], timeout: 1.0)
        
        let _ = sdkInstance.evalFeature(id: "qrscanpayment1")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment1")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment2")
        let _ = sdkInstance.evalFeature(id: "qrscanpayment2")
        
        XCTAssertEqual(2, countTrackingCallback)
    }
    
    // MARK: - Offline Mode

    /// When features are supplied at init and backgroundSync is false, the SDK must not
    /// make any network call on initialization. The developer drives updates manually via
    /// refreshCache().
    func testOfflineModeNoNetworkCallOnInit() throws {
        let featuresPayload = """
        {"features":{"dark-mode":{"defaultValue":false}}}
        """.data(using: .utf8)!

        let mockNetwork = MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)

        let _ = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: featuresPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: mockNetwork)
        .initializer()

        XCTAssertEqual(mockNetwork.callCount, 0, "No network call should be made when features are provided and backgroundSync is false")
    }

    /// When features are supplied at init, the SDK should use them immediately without
    /// going to disk first.
    func testOfflineModeUsesProvidedFeatures() throws {
        let featuresPayload = """
        {"features":{"dark-mode":{"defaultValue":true}}}
        """.data(using: .utf8)!

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: featuresPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        XCTAssertTrue(sdk.getFeatures().keys.contains("dark-mode"), "SDK should expose features from the provided payload immediately")
    }

    // MARK: - Stable Session Mode

    /// In stableSession mode, a remote refresh must update the cache but must NOT change
    /// the features the SDK evaluates against during the current session.
    func testStableSessionFeaturesNotAppliedOnRefresh() throws {
        let initialPayload = """
        {"features":{"session-feature":{"defaultValue":true}}}
        """.data(using: .utf8)!

        let refreshExpectation = XCTestExpectation(description: "refreshHandler called after remote refresh")

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: initialPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0  // expire immediately so the network call fires
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async { refreshExpectation.fulfill() }
        })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
        .initializer()

        // Trigger a manual refresh — network returns features including "onboarding"
        sdk.refreshCache()
        wait(for: [refreshExpectation], timeout: 2.0)

        // Session features must be unchanged: "session-feature" present, "onboarding" absent
        XCTAssertTrue(sdk.getFeatures().keys.contains("session-feature"),   "Original session feature must still be present")
        XCTAssertFalse(sdk.getFeatures().keys.contains("onboarding"),       "Network-refreshed feature must NOT be applied in stableSession mode")
    }

    /// After a first refreshCache() warms the on-disk cache with new features, a second
    /// refreshCache() must NOT apply those cached features to the live session.
    /// Without the sessionFeaturesLocked guard the cache-read path (isRemote:false) would
    /// silently bypass the stableSession block on the second call.
    func testStableSessionSecondRefreshAlsoBlocked() throws {
        let initialPayload = """
        {"features":{"session-feature":{"defaultValue":true}}}
        """.data(using: .utf8)!

        let firstRefresh  = XCTestExpectation(description: "First refresh handler called")
        let secondRefresh = XCTestExpectation(description: "Second refresh handler called")
        var refreshCount  = 0

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: initialPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async {
                refreshCount += 1
                if refreshCount == 1 { firstRefresh.fulfill() }
                else if refreshCount == 2 { secondRefresh.fulfill() }
            }
        })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
        .initializer()

        // First refresh — network writes "onboarding" to disk cache; live session must not change.
        sdk.refreshCache()
        wait(for: [firstRefresh], timeout: 2.0)
        XCTAssertTrue(sdk.getFeatures().keys.contains("session-feature"),  "session-feature must survive first refresh")
        XCTAssertFalse(sdk.getFeatures().keys.contains("onboarding"),      "onboarding must not apply after first refresh")

        // Second refresh — cache now contains "onboarding"; must still not leak into live session.
        sdk.refreshCache()
        wait(for: [secondRefresh], timeout: 2.0)
        XCTAssertTrue(sdk.getFeatures().keys.contains("session-feature"),  "session-feature must survive second refresh even after cache is warm with new features")
        XCTAssertFalse(sdk.getFeatures().keys.contains("onboarding"),      "onboarding must not apply even after cache-warmed second refresh")
    }

    /// An empty features payload is invalid in stableSession mode. The SDK must log a warning,
    /// fall back to a network fetch, apply those features to the session, then lock it.
    func testStableSessionWithEmptyInitialPayloadFallsBackToNetwork() throws {
        let emptyPayload = "{}".data(using: .utf8)!
        let refreshExpectation = XCTestExpectation(description: "refreshHandler called after network fetch")

        let mockClient = MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: emptyPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setStableSession(true)
        .setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async { refreshExpectation.fulfill() }
        })
        .setNetworkDispatcher(networkDispatcher: mockClient)
        .initializer()

        wait(for: [refreshExpectation], timeout: 2.0)
        XCTAssertGreaterThan(mockClient.callCount, 0,
            "Empty payload must trigger a network fetch in stableSession mode")
        XCTAssertTrue(sdk.getFeatures().keys.contains("onboarding"),
            "Network features should be applied when initial payload was empty")
    }

    /// An intentionally empty feature payload { "features": {} } must not trigger a network
    /// fetch — it is a deliberate empty config, not a missing config.
    func testOfflineModeEmptyFeaturesPayloadNoNetworkFetch() {
        let emptyPayload = """
        {"features":{}}
        """.data(using: .utf8)!

        let mockNetwork = MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: emptyPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: mockNetwork)
        .initializer()

        XCTAssertEqual(mockNetwork.callCount, 0,        "An intentionally empty feature payload must not trigger a network fetch")
        XCTAssertTrue(sdk.getFeatures().isEmpty,         "Feature set should be empty when an empty payload is provided")
    }

    /// A pre-fetched payload that uses encryptedFeatures must be decrypted at init
    /// so features are immediately available, with no network call required.
    func testOfflineModeEncryptedPreloadedPayload() throws {
        let ivString      = "vMSg2Bj/IurObDsWVmvkUg=="
        let featureJSON   = "{\"enc-session\":{\"defaultValue\":true}}"

        let crypto    = Crypto()
        let keyBytes  = Data(base64Encoded: testKeyString)!.map { $0 }
        let ivBytes   = Data(base64Encoded: ivString)!.map { $0 }
        let plainBytes = featureJSON.data(using: .utf8)!.map { $0 }

        let cipherBytes     = try crypto.encrypt(key: keyBytes, iv: ivBytes, plainText: plainBytes)
        let encryptedString = "\(ivString).\(Data(cipherBytes).base64EncodedString())"

        let payload = """
        {"encryptedFeatures":"\(encryptedString)"}
        """.data(using: .utf8)!

        let mockNetwork = MockNetworkClient(successResponse: nil, error: nil)

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            encryptionKey: testKeyString,
            attributes: [:],
            features: payload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: mockNetwork)
        .initializer()

        XCTAssertTrue(sdk.getFeatures().keys.contains("enc-session"), "Encrypted preloaded feature must be immediately available")
        XCTAssertEqual(mockNetwork.callCount, 0,                       "No network call should be made when encrypted payload is preloaded with backgroundSync:false")
    }

    /// stableSession: false (default) keeps the existing behaviour — refreshCache() applies immediately.
    func testDefaultModeAppliesFeaturesOnRefresh() throws {
        let initialPayload = """
        {"features":{"session-feature":{"defaultValue":true}}}
        """.data(using: .utf8)!

        let refreshExpectation = XCTestExpectation(description: "refreshHandler called")

        let sdk = GrowthBookBuilder(
            apiHost: testApiHost,
            clientKey: testClientKey,
            attributes: [:],
            features: initialPayload,
            trackingCallback: { _, _ in },
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setRefreshHandler(refreshHandler: { _ in
            DispatchQueue.main.async { refreshExpectation.fulfill() }
        })
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
        .initializer()

        sdk.refreshCache()
        wait(for: [refreshExpectation], timeout: 2.0)

        XCTAssertTrue(sdk.getFeatures().keys.contains("onboarding"), "Network-refreshed features should be applied immediately when stableSession is false")
    }

    func testAppendAttributes() throws {
        let sdkInstance = GrowthBookBuilder(apiHost: testApiHost,
                                            clientKey: testClientKey,
                                            attributes: [:],
                                            trackingCallback: { _, _ in },
                                            refreshHandler: nil,
                                            backgroundSync: false).initializer()
        
        
        sdkInstance.setAttributes(attributes: ["name": "Alice"])
        try sdkInstance.appendAttributes(attributes: ["age": 30])
        
        let result = sdkInstance.getGBContext().attributes
        XCTAssertEqual(result["name"].stringValue, "Alice")
        XCTAssertEqual(result["age"].intValue, 30)
        
        
        sdkInstance.setAttributes(attributes: ["user": ["id": 1, "name": "Alice"]])
        try sdkInstance.appendAttributes(attributes: ["user": ["name": "Bob", "age": 25]])
        
        let user = sdkInstance.getGBContext().attributes["user"]
        XCTAssertEqual(user["id"].intValue, 1)
        XCTAssertEqual(user["name"].stringValue, "Bob")
        XCTAssertEqual(user["age"].intValue, 25)
        
        
        sdkInstance.setAttributes(attributes: ["user": ["roles": ["admin", "editor"]]])
        try sdkInstance.appendAttributes(attributes: ["user": ["roles": ["viewer"]]])

        let roles = sdkInstance.getGBContext().attributes["user"]["roles"].arrayValue.map { $0.stringValue }
        XCTAssertEqual(roles, ["admin", "editor", "viewer"])
    }
}
