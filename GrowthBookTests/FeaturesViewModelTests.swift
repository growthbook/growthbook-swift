import XCTest

@testable import GrowthBook

class FeaturesViewModelTests: XCTestCase, FeaturesFlowDelegate {
    var isSuccess: Bool = false
    var isError: Bool = false

    func testSuccess() throws {
        isSuccess = false
        isError = true

        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), backgroundSync: false)

        viewModel.fetchFeatures(apiUrl: "", sseURL: "")

        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }

    func testSuccessForEncryptedFeatures() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), backgroundSync: false)
        
        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.fetchFeatures(apiUrl: "", sseURL: "")
        
        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testGetDataFromCache() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil)), backgroundSync: false)
        
        viewModel.fetchFeatures(apiUrl: "", sseURL: "")

        let cachingManager: CachingLayer = CachingManager()
        
        guard let featureData = cachingManager.getContent(fileName: Constants.featureCache) else {
            XCTFail()
            return
        }
        
        if let features = try? JSONDecoder().decode(Features.self, from: featureData), features != [:] {
            XCTAssertTrue(true)
        } else {
            XCTFail()
        }
        
        XCTAssertTrue(isSuccess)
        XCTAssertFalse(isError)
    }
    
    func testWithEncryptGetDataFromCache() throws {
        isSuccess = false
        isError = true
        
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponseEncryptedFeatures, error: nil)), backgroundSync: false)
        
        viewModel.encryptionKey = "3tfeoyW0wlo47bDnbWDkxg=="
        viewModel.fetchFeatures(apiUrl: "", sseURL: "")

        let cachingManager: CachingLayer = CachingManager()
        
        guard let featureData = cachingManager.getContent(fileName: Constants.featureCache) else {
            XCTFail()
            return
        }
        
        if let features = try? JSONDecoder().decode(Features.self, from: featureData), features != [:] {
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
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: .failedToLoadData)), backgroundSync: false)

        viewModel.fetchFeatures(apiUrl: "", sseURL: "")

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
    }

    func testInvalid() throws {
        isSuccess = false
        isError = true
        let viewModel = FeaturesViewModel(delegate: self, dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().errorResponse, error: nil)), backgroundSync: false)
        viewModel.fetchFeatures(apiUrl: "", sseURL: "")

        XCTAssertFalse(isSuccess)
        XCTAssertTrue(isError)
    }

    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {
        isSuccess = true
        isError = false
    }

    func featuresFetchFailed(error: SDKError, isRemote: Bool) {
        isSuccess = false
        isError = true
    }
}
