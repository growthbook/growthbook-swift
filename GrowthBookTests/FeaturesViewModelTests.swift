import XCTest

@testable import GrowthBook

class FeaturesViewModelTests: XCTestCase, FeaturesFlowDelegate {
    
    var isSuccess: Bool = false
    var isError: Bool = false
    var hasFeatures: Bool = false
    
    let cachingManager = CachingManager(apiKey: "features-vm-test-api-key")
    
    override func setUp() {
        super.setUp()
        
        isSuccess = false
        isError = true
        hasFeatures = false
    }

    func testSuccess() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), cachingManager: cachingManager)

        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
        XCTAssertTrue(hasFeatures)
    }

    func testSuccessForEncryptedFeatures() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), cachingManager: cachingManager)
        
        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testGetDataFromCache() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), cachingManager: cachingManager)
        
        viewModel.fetchFeatures(apiUrl: "")
        
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
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), cachingManager: cachingManager)
        
        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.fetchFeatures(apiUrl: "")
        
        guard let featureData = cachingManager.getContent(fileName: Constants.featureCache) else {
            XCTFail()
            return
        }
        
        if let _ = try? JSONDecoder().decode(Features.self, from: featureData) {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
        
        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testError() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: .failedToLoadData)), cachingManager: cachingManager)

        viewModel.fetchFeatures(apiUrl: "")

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
        XCTAssertFalse(hasFeatures)
    }

    func testInvalid() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().errorResponse, error: nil)), cachingManager: cachingManager)
        viewModel.fetchFeatures(apiUrl: "")

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
