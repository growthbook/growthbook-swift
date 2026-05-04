import XCTest
@testable import GrowthBook

class FeaturesViewModelExtendedTests: XCTestCase {

    // MARK: - Delegate capture

    private class Capture: FeaturesFlowDelegate {
        var successCount = 0
        var failCount = 0
        var savedGroupsCount = 0
        var lastError: SDKError?
        var lastFeatures: Features?
        var lastSavedGroups: JSON?

        func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {
            successCount += 1
            lastFeatures = features
        }
        func featuresFetchFailed(error: SDKError, isRemote: Bool) {
            failCount += 1
            lastError = error
        }
        func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
            savedGroupsCount += 1
            lastSavedGroups = savedGroups
        }
        func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) { failCount += 1 }
        func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    }

    private func makeVM(
        response: String? = nil,
        error: Error? = nil,
        delegate: FeaturesFlowDelegate,
        ttlSeconds: Int = 60,
        apiKey: String = UUID().uuidString,
        preloadedFeatures: Features? = nil
    ) -> FeaturesViewModel {
        let manager = CachingManager(apiKey: apiKey)
        manager.clearCache()
        let dataSource = FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: response, error: error))
        return FeaturesViewModel(
            delegate: delegate,
            dataSource: dataSource,
            cachingManager: manager,
            ttlSeconds: ttlSeconds,
            preloadedFeatures: preloadedFeatures
        )
    }

    // MARK: - preloadedFeatures skips cache read

    func testPreloadedFeaturesSkipsCacheRead() {
        let capture = Capture()
        // preloadedFeatures is provided → fetchCachedFeatures is NOT called
        // so no featuresFetchFailed from empty cache
        let preloaded: Features = ["flag": Feature(defaultValue: JSON(true))]
        _ = makeVM(delegate: capture, preloadedFeatures: preloaded)
        // With preloadedFeatures, the VM skips the cache → no success or fail from cache
        XCTAssertEqual(capture.successCount, 0)
        XCTAssertEqual(capture.failCount, 0)
    }

    func testNoPreloadedFeaturesReadsCache() {
        let capture = Capture()
        // No preloadedFeatures and empty cache → featuresFetchFailed
        _ = makeVM(delegate: capture)
        XCTAssertEqual(capture.failCount, 1)
        XCTAssertEqual(capture.lastError, .failedToLoadData)
    }

    // MARK: - fetchFeatures with nil apiUrl skips network

    func testFetchFeaturesNilApiUrlSkipsNetwork() {
        let capture = Capture()
        let vm = makeVM(response: MockResponse().successResponse, delegate: capture, ttlSeconds: 0)
        let beforeFail = capture.failCount
        vm.fetchFeatures(apiUrl: nil)
        // No network call → no additional success
        XCTAssertEqual(capture.successCount, 0)
        XCTAssertEqual(capture.failCount, beforeFail + 1) // one more fail from cache read in fetchFeatures
    }

    // MARK: - remoteEval path

    func testFetchFeaturesRemoteEvalSuccess() {
        let capture = Capture()
        let vm = makeVM(response: MockResponse().successResponse, delegate: capture, ttlSeconds: 0)
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)
        // Remote eval success should trigger featuresFetchedSuccessfully
        XCTAssertGreaterThan(capture.successCount, 0)
    }

    func testFetchFeaturesRemoteEvalFailure() {
        let capture = Capture()
        let vm = makeVM(error: SDKError.failedToFetchData, delegate: capture, ttlSeconds: 0)
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)
        XCTAssertGreaterThan(capture.failCount, 0)
    }

    // MARK: - prepareFeaturesData: encryptedFeatures without key

    func testPrepareFeaturesDataEncryptedFeaturesWithoutKeyFails() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        // encryptedFeatures present but no encryptionKey set
        let payload = """
        {"status":200,"encryptedFeatures":"someencryptedstring==.abc"}
        """.data(using: .utf8)!
        vm.prepareFeaturesData(data: payload)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedMissingKey)
    }

    func testPrepareFeaturesDataEncryptedFeaturesWithWrongKeyFails() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        vm.encryptionKey = "wrong-key-that-is-short"
        let payload = """
        {"status":200,"encryptedFeatures":"someencryptedstring==.abc"}
        """.data(using: .utf8)!
        vm.prepareFeaturesData(data: payload)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedEncryptedFeatures)
    }

    // MARK: - prepareFeaturesData: no features and no encryptedFeatures

    func testPrepareFeaturesDataNoFeaturesFails() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        let payload = """
        {"status":200}
        """.data(using: .utf8)!
        vm.prepareFeaturesData(data: payload)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedMissingKey)
    }

    // MARK: - prepareFeaturesData: plain features success

    func testPrepareFeaturesDataPlainFeaturesSuccess() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        let payload = """
        {"status":200,"features":{"my-flag":{"defaultValue":true}}}
        """.data(using: .utf8)!
        vm.prepareFeaturesData(data: payload)
        XCTAssertEqual(capture.successCount, 1)
        XCTAssertNotNil(capture.lastFeatures?["my-flag"])
    }

    // MARK: - prepareFeaturesData: invalid JSON fails

    func testPrepareFeaturesDataInvalidJsonFails() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        vm.prepareFeaturesData(data: "not json".data(using: .utf8)!)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedParsedData)
    }

    // MARK: - prepareFeaturesData: savedGroups in response

    func testPrepareFeaturesDataWithSavedGroups() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        let payload = """
        {"status":200,"features":{"f":{"defaultValue":1}},"savedGroups":{"team":["a","b"]}}
        """.data(using: .utf8)!
        vm.prepareFeaturesData(data: payload)
        XCTAssertEqual(capture.savedGroupsCount, 1)
        XCTAssertNotNil(capture.lastSavedGroups)
    }

    // MARK: - fetchFeatures network failure falls back to cache

    func testFetchFeaturesNetworkFailureFallsBackToCache() {
        let capture = Capture()
        // First populate cache
        let apiKey = UUID().uuidString
        let manager = CachingManager(apiKey: apiKey)
        manager.clearCache()

        // Populate cache via a successful VM
        let populateCapture = Capture()
        let populateVM = FeaturesViewModel(
            delegate: populateCapture,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(
                successResponse: MockResponse().successResponse, error: nil
            )),
            cachingManager: manager,
            ttlSeconds: 0
        )
        populateVM.fetchFeatures(apiUrl: "https://example.com")

        // Now fail the network → should fall back to cache
        let failVM = FeaturesViewModel(
            delegate: capture,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(
                successResponse: nil, error: SDKError.failedToFetchData
            )),
            cachingManager: manager,
            ttlSeconds: 0
        )
        failVM.fetchFeatures(apiUrl: "https://example.com")
        // After network fail, falls back to cache → at least one success
        XCTAssertGreaterThan(capture.successCount, 0)
    }
}
