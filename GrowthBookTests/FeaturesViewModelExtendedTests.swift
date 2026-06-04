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

        // featuresUpdateIsComplete
        
        var featuresUpdateIsCompleteCallCount = 0
        var featuresUpdateIsCompleteArguments: [(error: GrowthBook.SDKError?, isRemote: Bool)] = []

        func featuresUpdateIsComplete(error: GrowthBook.SDKError?, isRemote: Bool) {
            featuresUpdateIsCompleteArguments += [(error, isRemote)]
            featuresUpdateIsCompleteCallCount += 1
        }
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 0)
    }

    func testNoPreloadedFeaturesReadsCache() {
        let capture = Capture()
        // No preloadedFeatures and empty cache → featuresFetchFailed
        _ = makeVM(delegate: capture)
        XCTAssertEqual(capture.failCount, 1)
        XCTAssertEqual(capture.lastError, .failedToLoadData)
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 0)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1) // fetchFeatures
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error, .invalidAPIURL)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].isRemote, false)
    }

    // MARK: - remoteEval path

    func testFetchFeaturesRemoteEvalSuccess() {
        let capture = Capture()
        let vm = makeVM(response: MockResponse().successResponse, delegate: capture, ttlSeconds: 0)
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)
        // Remote eval success should trigger featuresFetchedSuccessfully
        XCTAssertGreaterThan(capture.successCount, 0)
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertNil(capture.featuresUpdateIsCompleteArguments[0].error)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
    }

    func testFetchFeaturesRemoteEvalFailure() {
        let capture = Capture()
        let vm = makeVM(error: SDKError.failedToFetchData, delegate: capture, ttlSeconds: 0)
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedToLoadData)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedMissingKey)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedEncryptedFeatures)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedMissingKey)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertNil(capture.featuresUpdateIsCompleteArguments[0].error)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
    }

    // MARK: - prepareFeaturesData: invalid JSON fails

    func testPrepareFeaturesDataInvalidJsonFails() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        vm.prepareFeaturesData(data: "not json".data(using: .utf8)!)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedParsedData)
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedParsedData)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertNil(capture.featuresUpdateIsCompleteArguments[0].error)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
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
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[0].error?.code, .failedToFetchData)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)
    }

    // MARK: - persistent TTL survives VM restart

    func testCachedAtTimestampSkipsNetworkOnRestart() {
        let apiKey = UUID().uuidString
        let manager = CachingManager(apiKey: apiKey)
        manager.clearCache()

        // First VM: fetch successfully, writes cachedAt to disk
        let firstClient = MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)
        let firstCapture = Capture()
        let firstVM = FeaturesViewModel(
            delegate: firstCapture,
            dataSource: FeaturesDataSource(dispatcher: firstClient),
            cachingManager: manager,
            ttlSeconds: 3600
        )
        firstVM.fetchFeatures(apiUrl: "https://example.com")
        XCTAssertEqual(firstClient.callCount, 1)

        // Second VM simulates cold restart with same cache — TTL still fresh, no network call
        let secondClient = MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)
        let secondCapture = Capture()
        let secondVM = FeaturesViewModel(
            delegate: secondCapture,
            dataSource: FeaturesDataSource(dispatcher: secondClient),
            cachingManager: manager,
            ttlSeconds: 3600
        )
        secondVM.fetchFeatures(apiUrl: "https://example.com")
        XCTAssertEqual(secondClient.callCount, 0, "Network should not be called when cache is fresh after restart")
        XCTAssertGreaterThan(secondCapture.successCount, 0, "Cache should still serve features")
    }

    // MARK: - SSE empty / heartbeat payload handling

    /// Empty SSE data ("") must not reach prepareFeaturesData.
    /// Regression: before the fix, `"".data(using: .utf8)` is non-nil so the guard
    /// `guard let jsonData = data?.data(using: .utf8)` passed, triggering a spurious
    /// featuresFetchFailed(error: .failedParsedData) call.
    func testPrepareFeaturesDataEmptyPayloadTriggersError() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        vm.prepareFeaturesData(data: Data())
        XCTAssertGreaterThan(capture.failCount, 0, "Empty Data should be treated as a parse error")
        XCTAssertEqual(capture.lastError, .failedParsedData)
    }

    /// SSE comment lines (heartbeat / keepalive, e.g. ": heartbeat") must be filtered
    /// before any listener is invoked — SSEEvent.init returns nil for them.
    func testSSEEventHeartbeatCommentIsNil() {
        let newlines = ["\r\n", "\n", "\r"]
        XCTAssertNil(SSEEvent(eventString: ": heartbeat", newLineCharacters: newlines))
        XCTAssertNil(SSEEvent(eventString: ":", newLineCharacters: newlines))
        XCTAssertNil(SSEEvent(eventString: ": keepalive", newLineCharacters: newlines))
    }

    /// A well-formed SSE event with an empty data field should produce a non-nil SSEEvent
    /// whose data property is the empty string — confirming the guard `!data.isEmpty` in
    /// connectBackgroundSync is what prevents the empty payload from reaching prepareFeaturesData.
    func testSSEEventEmptyDataFieldIsEmptyString() {
        let newlines = ["\r\n", "\n", "\r"]
        let event = SSEEvent(eventString: "event: features\ndata: ", newLineCharacters: newlines)
        XCTAssertNotNil(event)
        XCTAssertEqual(event?.data ?? "non-empty", "")
    }

    /// An SSE event with a valid JSON payload must be passed through to prepareFeaturesData
    /// and result in a successful feature load.
    func testSSEEventValidJsonPayloadProducesSuccess() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        let validJSON = """
        {"status":200,"features":{"sse-flag":{"defaultValue":true}}}
        """
        vm.prepareFeaturesData(data: validJSON.data(using: .utf8)!)
        XCTAssertEqual(capture.successCount, 1)
        XCTAssertNotNil(capture.lastFeatures?["sse-flag"])
    }

    /// An SSE event with an invalid JSON payload must not crash and must fire featuresFetchFailed.
    func testSSEEventInvalidJsonPayloadProducesError() {
        let capture = Capture()
        let vm = makeVM(delegate: capture)
        vm.prepareFeaturesData(data: "not-json".data(using: .utf8)!)
        XCTAssertGreaterThan(capture.failCount, 0)
        XCTAssertEqual(capture.lastError, .failedParsedData)
    }

    // MARK: - fetchFeatures is not stale reports featuresAreUpToDate to the delegate

    func testFetchFeaturesReportIfNotStale() {
        // GIVEN
        let capture = Capture()
        let vm = makeVM(response: MockResponse().successResponse, delegate: capture, ttlSeconds: 100)
        // first successful fetch
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)
        XCTAssertGreaterThan(capture.successCount, 0)
        // no featuresAreUpToDate callse
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 1)
        XCTAssertNil(capture.featuresUpdateIsCompleteArguments[0].error)
        XCTAssertTrue(capture.featuresUpdateIsCompleteArguments[0].isRemote)

        // WHEN
        // trying to fetch while cache is not expired
        vm.fetchFeatures(apiUrl: "https://example.com", remoteEval: true)

        // THEN
        XCTAssertEqual(capture.featuresUpdateIsCompleteCallCount, 2, "Expected to call featuresAreUpToDate delegate method")
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[1].error, nil)
        XCTAssertEqual(capture.featuresUpdateIsCompleteArguments[1].isRemote, true)
    }
}
