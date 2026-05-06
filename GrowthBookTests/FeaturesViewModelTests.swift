import XCTest

@testable import GrowthBook

class FeaturesViewModelTests: XCTestCase, FeaturesFlowDelegate {
    
    var isSuccess: Bool = false
    var isError: Bool = false
    var hasFeatures: Bool = false
    var ttlSeconds = 60
    
    let cachingManager: CachingLayer = CachingManager()
    
    override func setUp() {
        super.setUp()
        
        isSuccess = false
        isError = true
        hasFeatures = false
    }

    func testSuccess() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)

        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }

    func testSuccessForEncryptedFeatures() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        
        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testGetDataFromCache() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        
        viewModel.fetchFeatures(apiUrl: "")

        let cachingManager: CachingLayer = CachingManager()
        
        guard let featureData = cachingManager.getContent(fileName: Constants.featureCache) else {
            XCTFail()
            return
        }
        
        guard let savedGroupsData = cachingManager.getContent(fileName: Constants.savedGroupsCache) else {
            XCTFail()
            return
        }
        
        if let features = try? JSONDecoder().decode(Features.self, from: featureData), features != [:] {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
        
        if let _ = try? JSONDecoder().decode(JSON.self, from: savedGroupsData) {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
        
        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }
    
    func testWithEncryptGetDataFromCache() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        
        let encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.encryptionKey = encryptionKey
        viewModel.fetchFeatures(apiUrl: "")

        let cachingManager: CachingLayer = CachingManager()
        
        guard let featureData = cachingManager.getContent(fileName: Constants.featureCache) else {
            XCTFail()
            return
        }
        
        let crypto: CryptoProtocol = Crypto()
        if let encryptedString = String(data: featureData, encoding: .utf8), crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) != nil {
            XCTAssertTrue(true)
        } else if let _ = try? JSONDecoder().decode(Features.self, from: featureData) {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
        
        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testSavedGroupsRestoredFromCacheOnRestart() throws {
        // Simulate first launch: fetch from network, savedGroups written to cache
        let firstVM = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        firstVM.fetchFeatures(apiUrl: "")
        XCTAssertTrue(isSuccess)

        // Simulate app restart: new VM reads only from cache, no network
        var savedGroupsFromCache: JSON? = nil
        let captureDelegate = SavedGroupsCapture { savedGroupsFromCache = $0 }
        let restartVM = FeaturesViewModel(
            delegate: captureDelegate,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: SDKError.failedToLoadData)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        _ = restartVM

        XCTAssertNotNil(savedGroupsFromCache, "savedGroups should be restored from cache on restart")
        XCTAssertFalse(savedGroupsFromCache?.dictionaryValue.isEmpty ?? true, "savedGroups should not be empty")
    }

    func test304NotModifiedTreatedAsSuccess() throws {
        // First fetch to populate cache
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        viewModel.fetchFeatures(apiUrl: "")
        XCTAssertTrue(isSuccess)

        // Second fetch returns 304 — should still be success, not error
        isSuccess = false
        isError = true
        let notModifiedError = NSError(domain: "HTTPError", code: 304, userInfo: [NSLocalizedDescriptionKey: "Not Modified - Use cached data"])
        let viewModel304 = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: notModifiedError as Error?)), cachingManager: cachingManager, ttlSeconds: 0)
        viewModel304.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }

    // MARK: - Large Saved Group tests (reproduces the 10k-record payload bug)

    func testLargeSavedGroupPayloadParsedSuccessfully() throws {
        let ids = (1...10_000).map { "\($0)" }
        let idsJSON = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let payload = """
        {
            "status": 200,
            "features": { "large_group_feature": { "defaultValue": false } },
            "savedGroups": { "large_group": [\(idsJSON)] }
        }
        """

        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: payload, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess, "SDK should parse a 10k-record savedGroup without error")
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }

    func testLargeSavedGroupIsPersistedToCache() throws {
        let ids = (1...10_000).map { "\($0)" }
        let idsJSON = ids.map { "\"\($0)\"" }.joined(separator: ",")
        let payload = """
        {
            "status": 200,
            "features": { "large_group_feature": { "defaultValue": false } },
            "savedGroups": { "large_group": [\(idsJSON)] }
        }
        """

        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: payload, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        viewModel.fetchFeatures(apiUrl: "")

        guard let cachedData = cachingManager.getContent(fileName: Constants.savedGroupsCache) else {
            XCTFail("savedGroups should be written to cache after a large payload fetch")
            return
        }
        let decoded = try? JSONDecoder().decode(JSON.self, from: cachedData)
        XCTAssertNotNil(decoded, "Cached savedGroups should be valid JSON")
        XCTAssertEqual(decoded?["large_group"].arrayValue.count, 10_000)
    }

    func testFallbackToCacheWhenLargePayloadNetworkFails() throws {
        // Populate cache with a valid response first
        let seedVM = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        seedVM.fetchFeatures(apiUrl: "")
        XCTAssertTrue(isSuccess, "Seed fetch should succeed")

        // Simulate the large-payload timeout that Cloudflare/Proxy triggers
        isSuccess = false
        isError = true
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                                   userInfo: [NSLocalizedDescriptionKey: "The request timed out"])
        let failingVM = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: timeoutError)),
            cachingManager: cachingManager,
            ttlSeconds: 0 // force network attempt
        )
        failingVM.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        XCTAssertTrue(isSuccess, "SDK should serve cached features when network fails due to large payload")
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }

    func testUnderlyingErrorPreservedOnNetworkFailure() throws {
        let networkError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut,
                                   userInfo: [NSLocalizedDescriptionKey: "The request timed out"])
        var capturedErrors: [SDKError] = []
        let capture = ErrorCapture { capturedErrors.append($0) }

        let viewModel = FeaturesViewModel(
            delegate: capture,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: networkError)),
            cachingManager: CachingManager(),
            ttlSeconds: 0
        )
        viewModel.manager.clearCache()
        viewModel.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        let fetchError = capturedErrors.first(where: { $0.code == .failedToFetchData })
        XCTAssertNotNil(fetchError, "failedToFetchData must be reported")
        XCTAssertNotNil(fetchError?.underlying, "Underlying network error must be forwarded to the caller")
        XCTAssertEqual((fetchError?.underlying as NSError?)?.code, NSURLErrorTimedOut)
    }

    func testFeaturesSuccessCallbackFiredWithIsRemoteAfterCacheFallback() throws {
        // Populate cache
        let seedVM = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )
        seedVM.fetchFeatures(apiUrl: "")
        XCTAssertTrue(isSuccess)

        // Network fails — ViewModel must call featuresFetchedSuccessfully(isRemote: true)
        // so that GrowthBookSDK's refreshHandler receives nil (success), not an error.
        var fetchFailedCalledRemote = false
        var successCalledRemote = false
        let capture = RemoteCallCapture(
            onSuccess: { isRemote in if isRemote { successCalledRemote = true } },
            onFailure: { isRemote in if isRemote { fetchFailedCalledRemote = true } }
        )
        let timeoutError = NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
        let vm = FeaturesViewModel(
            delegate: capture,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: timeoutError)),
            cachingManager: cachingManager,
            ttlSeconds: 0
        )
        vm.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        XCTAssertTrue(fetchFailedCalledRemote, "featuresFetchFailed(isRemote: true) must be reported for network error")
        XCTAssertTrue(successCalledRemote, "featuresFetchedSuccessfully(isRemote: true) must be called after cache fallback so refreshHandler receives nil")
    }

    func testError() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: .failedToLoadData)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)

        viewModel.manager.clearCache()
        
        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
        XCTAssertFalse(hasFeatures)
    }

    func testInvalid() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().errorResponse, error: nil)), cachingManager: cachingManager, ttlSeconds: ttlSeconds)
        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
        XCTAssertFalse(hasFeatures)
    }

    /// Regression test: payloads that include `filters` with array-encoded `ranges`
    /// (e.g. `[[0, 0.75]]`) were causing a full decode failure because BucketRange's
    /// synthesised Codable expected a keyed object, not a bare `[Float, Float]` array.
    func testSuccessWithFiltersPayload() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(
                dispatcher: MockNetworkClient(
                    successResponse: MockResponse().successResponseWithFilters,
                    error: nil
                )
            ),
            cachingManager: cachingManager,
            ttlSeconds: ttlSeconds
        )

        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess, "Expected successful feature fetch with filters payload")
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }

    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {
        isSuccess = true
        isError = false
        hasFeatures = !features.isEmpty
    }

    func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        isSuccess = false
        isError = true
        hasFeatures = false
    }
    
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {
        isSuccess = false
        isError = true
    }
    
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        isSuccess = true
        isError = false
    }
    
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {

    }
}

private class SavedGroupsCapture: FeaturesFlowDelegate {
    private let onSavedGroups: (JSON) -> Void

    init(_ onSavedGroups: @escaping (JSON) -> Void) {
        self.onSavedGroups = onSavedGroups
    }

    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {}
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    func featuresFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {
        onSavedGroups(savedGroups)
    }
}

private class RemoteCallCapture: FeaturesFlowDelegate {
    private let onSuccess: (Bool) -> Void
    private let onFailure: (Bool) -> Void
    init(onSuccess: @escaping (Bool) -> Void, onFailure: @escaping (Bool) -> Void) {
        self.onSuccess = onSuccess
        self.onFailure = onFailure
    }
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) { onSuccess(isRemote) }
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    func featuresFetchFailed(error: SDKError, isRemote: Bool) { onFailure(isRemote) }
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {}
}

private class ErrorCapture: FeaturesFlowDelegate {
    private let onError: (SDKError) -> Void
    init(_ onError: @escaping (SDKError) -> Void) { self.onError = onError }
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {}
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    func featuresFetchFailed(error: SDKError, isRemote: Bool) { onError(error) }
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {}
}
