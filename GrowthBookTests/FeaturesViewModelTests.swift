import XCTest

@testable import GrowthBook

class FeaturesCacheInterfaceMock: FeaturesCacheInterface, @unchecked Sendable {
    var underlyingValue: GrowthBook.Features?
    var rawData: Data?

    func features() throws -> GrowthBook.Features? {
        underlyingValue
    }
    
    func updateFeatures(_ value: GrowthBook.Features?) throws {
        underlyingValue = value
        rawData = try? underlyingValue.map(JSONEncoder().encode(_:))
    }
    
    func setEncodedFeaturesRawData(_ data: Data) throws {
        rawData = data
    }

    var didCallClearCache: Bool = false
    func clearCache() throws {
        didCallClearCache = true
        underlyingValue = nil
        rawData = nil
    }
}

class SavedGroupsCacheInterfaceMock: SavedGroupsCacheInterface, @unchecked Sendable {
    var underlyingValue: GrowthBook.JSON?

    func savedGroups() throws -> GrowthBook.JSON? {
        underlyingValue
    }

    func updateSavedGroups(_ value: GrowthBook.JSON?) throws {
        underlyingValue = value
    }

    var didCallClearCache: Bool = false
    func clearCache() throws {
        didCallClearCache = true
        underlyingValue = nil
    }
}

class FeaturesModelFetcherInterfaceMock: FeaturesModelFetcherInterface, @unchecked Sendable {
    var result: Result<GrowthBook.FeaturesModelResponse, any Error>?

    init(result: Result<GrowthBook.FeaturesModelResponse, any Error>? = nil) {
        self.result = result
    }

    func fetchFeatures(fetchResult callback: @escaping @Sendable (Result<GrowthBook.FeaturesModelResponse, any Error>) -> Void) {
        guard let result else {
            XCTFail("Result is not set")
            return
        }
        callback(result)
    }
}

extension DecryptedFeaturesDataModel {
    static func mock(dateUpdated: String? = nil, features: Features = [:], savedGroups: JSON = .null, experiments: [Experiment] = []) -> DecryptedFeaturesDataModel {
        .init(dateUpdated: dateUpdated, features: features, savedGroups: savedGroups, experiments: experiments)
    }
}

extension FeaturesModelResponse {
    static func mock(decryptedFeaturesDataModel: DecryptedFeaturesDataModel = .mock(), expiresInSeconds: Int = 30) -> FeaturesModelResponse {
        .init(decryptedFeaturesDataModel: decryptedFeaturesDataModel, expiresInSeconds: expiresInSeconds)
    }
}


class FeaturesViewModelTests: XCTestCase, FeaturesFlowDelegate {
    func featuresAPIModelSuccessfully(model: GrowthBook.DecryptedFeaturesDataModel, fetchType: GrowthBook.GrowthBookFeaturesFetchResult.FetchType) {
        isSuccess = true
        isError = false
        hasFeatures = !model.features.isEmpty
    }
    
    func featuresFetchFailed(error: any Error, fetchType: GrowthBook.GrowthBookFeaturesFetchResult.FetchType) {
        isSuccess = false
        isError = true
        hasFeatures = false
    }
    
    
    var isSuccess: Bool = false
    var isError: Bool = false
    var hasFeatures: Bool = false

    override func setUp() {
        super.setUp()
        
        isSuccess = false
        isError = true
//        hasFeatures = false
    }

    func testSuccess() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(
            delegate: self,
            featuresCache: FeaturesCacheInterfaceMock(),
            savedGroupsCache: SavedGroupsCacheInterfaceMock(),
            featuresModelProvider: .none,
            featuresModelFetcher: FeaturesModelFetcherInterfaceMock(result: .success(.mock()))
        )

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
//        XCTAssertTrue(hasFeatures)
    }

    func testSuccessForEncryptedFeatures() throws {
//        isSuccess = false
//        isError = true
//        
//        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), featuresCache: FeaturesCacheInterfaceMock(), savedGroupsCache: SavedGroupsCacheInterfaceMock())

        #warning("Check encryption in other test case")
//        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
//        viewModel.fetchFeatures(apiUrl: "")
//
//        XCTAssertTrue(isSuccess)
//        XCTAssertFalse(isError)
    }
    
//    func testGetDataFromCache() throws {
//        isSuccess = false
//        isError = true
//
//        let featuresCache = FeaturesCacheInterfaceMock()
//        let savedGroupsCache = SavedGroupsCacheInterfaceMock()
//
//        let viewModel = FeaturesViewModel(
//            delegate: self,
//            featuresCache: FeaturesCacheInterfaceMock(),
//            savedGroupsCache: SavedGroupsCacheInterfaceMock(),
//            featuresModelProvider: .none,
//            featuresModelFetcher: FeaturesModelFetcherInterfaceMock(result: .success(.mock()))
//        )
//
//        viewModel.fetchFeaturesOnce()
//
//
//        XCTAssertNotNil(try featuresCache.features())
//        XCTAssertNotNil(try savedGroupsCache.savedGroups())
//        
//        XCTAssertTrue(isSuccess)
//        XCTAssertFalse(isError)
////        XCTAssertTrue(hasFeatures)
//    }
    
//    func testWithEncryptGetDataFromCache() throws {
//        isSuccess = false
//        isError = true
//
//        let featuresCache = FeaturesCacheInterfaceMock()
//
//        let viewModel = FeaturesViewModel(
//            delegate: self,
//            featuresCache: FeaturesCacheInterfaceMock(),
//            savedGroupsCache: SavedGroupsCacheInterfaceMock(),
//            featuresModelProvider: .none,
//            featuresModelFetcher: FeaturesModelFetcherInterfaceMock(result: .failure(NSError(domain: "", code: -5)))
//        )
//
//        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
//        viewModel.fetchFeatures(apiUrl: "")
//
//        XCTAssertNotNil(try featuresCache.features())
//        
//        XCTAssertTrue(isSuccess)
//        XCTAssertFalse(isError)
//    }
    
    func testError() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(
            delegate: self,
            featuresCache: FeaturesCacheInterfaceMock(),
            savedGroupsCache: SavedGroupsCacheInterfaceMock(),
            featuresModelProvider: .none,
            featuresModelFetcher: FeaturesModelFetcherInterfaceMock(result: .failure(NSError(domain: "", code: -5)))
        )

        viewModel.fetchFeaturesOnce()

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
        XCTAssertFalse(hasFeatures)
    }

    func testInvalid() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(
            delegate: self,
            featuresCache: FeaturesCacheInterfaceMock(),
            savedGroupsCache: SavedGroupsCacheInterfaceMock(),
            featuresModelProvider: .none,
            featuresModelFetcher: FeaturesModelFetcherInterfaceMock(result: .failure(NSError(domain: "", code: -5)))
        )

        viewModel.fetchFeaturesOnce()

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
        XCTAssertFalse(hasFeatures)
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
