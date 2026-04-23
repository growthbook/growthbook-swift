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
