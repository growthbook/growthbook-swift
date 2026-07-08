import XCTest

@testable import GrowthBook

final class CacheMetadataTests: XCTestCase, FeaturesFlowDelegate {

    let cachingManager: CachingLayer = CachingManager(apiKey: "cache-metadata-tests")

    override func setUp() {
        super.setUp()
        cachingManager.clearCache()
    }

    // MARK: - FeaturesViewModel level

    func testMetadataEmptyBeforeAnyRefresh() throws {
        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: SDKError.failedToLoadData)),
            cachingManager: cachingManager,
            ttlSeconds: 60
        )

        let metadata = viewModel.cacheMetadata
        XCTAssertNil(metadata.lastRefresh, "No refresh has happened yet")
        XCTAssertNil(metadata.cacheAge)
        XCTAssertNil(metadata.expiresAt)
        XCTAssertTrue(metadata.isExpired, "An unrefreshed cache must report as expired")
    }

    func testMetadataPopulatedAfterSuccessfulRefresh() throws {
        let ttl = 60
        let before = Date()
        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: ttl
        )
        viewModel.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")
        let after = Date()

        let metadata = viewModel.cacheMetadata
        let lastRefresh = try XCTUnwrap(metadata.lastRefresh, "lastRefresh must be set after a successful fetch")
        let expiresAt = try XCTUnwrap(metadata.expiresAt)
        let cacheAge = try XCTUnwrap(metadata.cacheAge)

        XCTAssertGreaterThanOrEqual(lastRefresh.timeIntervalSince1970, before.timeIntervalSince1970)
        XCTAssertLessThanOrEqual(lastRefresh.timeIntervalSince1970, after.timeIntervalSince1970)
        XCTAssertEqual(expiresAt.timeIntervalSince(lastRefresh), Double(ttl), accuracy: 0.001)
        XCTAssertGreaterThanOrEqual(cacheAge, 0)
        XCTAssertFalse(metadata.isExpired, "A fresh cache with a positive TTL must not be expired")
    }

    func testMetadataReportsExpiredWithZeroTTL() throws {
        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: 0
        )
        viewModel.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        let metadata = viewModel.cacheMetadata
        XCTAssertNotNil(metadata.lastRefresh, "A refresh still occurred even with a zero TTL")
        XCTAssertTrue(metadata.isExpired, "A zero-TTL cache must report as immediately expired")
    }

    func testCacheAgeIsRecomputedOnEachAccess() throws {
        let viewModel = FeaturesViewModel(
            delegate: self,
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)),
            cachingManager: cachingManager,
            ttlSeconds: 60
        )
        viewModel.fetchFeatures(apiUrl: "https://cdn.growthbook.io/api/features/key")

        let firstAge = try XCTUnwrap(viewModel.cacheMetadata.cacheAge)
        Thread.sleep(forTimeInterval: 0.05)
        let secondAge = try XCTUnwrap(viewModel.cacheMetadata.cacheAge)
        XCTAssertGreaterThan(secondAge, firstAge, "cacheAge must grow between accesses")
    }

    // MARK: - Public GrowthBookSDK API

    func testSDKExposesCacheMetadata() throws {
        let sdk = GrowthBookBuilder(
            apiHost: "https://host.com",
            clientKey: "cache-metadata-tests",
            encryptionKey: nil,
            attributes: JSON(),
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
        .initializer()

        // initializer() triggers refreshCache() when no preloaded payload is supplied.
        let metadata = sdk.cacheMetadata
        XCTAssertNotNil(metadata.lastRefresh, "The SDK must expose the last refresh after initialization fetched features")
        XCTAssertNotNil(metadata.expiresAt)
        XCTAssertFalse(metadata.isExpired)
    }

    // MARK: - FeaturesFlowDelegate (no-op sink)

    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {}
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    func featuresFetchFailed(error: SDKError, isRemote: Bool) {}
    func contextualBanditsFetchFailed(error: SDKError, isRemote: Bool) {}
    func contextualBanditsFetchedSuccessfully(contextualBandits: JSON, isRemote: Bool) {}
    func contextualBanditsCleared(isRemote: Bool) {}
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {}
    func featuresUpdateIsComplete(error: SDKError?, isRemote: Bool) {}
}
