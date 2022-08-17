import XCTest

@testable import GrowthBook

class FeaturesViewModelTests: XCTestCase {

    func testSuccess() throws {
        let datasource = FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().successResponse, error: nil))
        let viewModel = FeaturesViewModel(dataSource: datasource, cachingLayer: MockCachingLayer())

        let completedExpectation = expectation(description: "Completed")
        viewModel.fetchFeatures(apiUrl: "") { result, _ in
            if case .success = result {
                completedExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testError() throws {

        let datasource = FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: .failedToLoadData))
        let viewModel = FeaturesViewModel(dataSource: datasource, cachingLayer: MockCachingLayer())

        let errorExpectation = expectation(description: "Error")
        viewModel.fetchFeatures(apiUrl: "") { result, _ in
            if case .failure = result {
                errorExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 0.3, handler: nil)
    }

    func testInvalid() throws {

        let datasource = FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: MockResponse().errorResponse, error: nil))
        let viewModel = FeaturesViewModel(dataSource: datasource, cachingLayer: MockCachingLayer())
        
        let errorExpectation = expectation(description: "Invalid")
        viewModel.fetchFeatures(apiUrl: "") { result, _ in
            if case .failure = result {
                errorExpectation.fulfill()
            }
        }

        waitForExpectations(timeout: 0.3, handler: nil)
    }
}
