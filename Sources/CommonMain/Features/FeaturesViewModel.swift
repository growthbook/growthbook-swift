import Foundation

/// Interface for Feature API Completion Events
public protocol FeaturesFlowDelegate: AnyObject {
    func featuresFetchedSuccessfully(features: [String: Feature], isRemote: Bool)
    func featuresFetchFailed(error: SDKError, isRemote: Bool)
}

/// View Model for Features
public class FeaturesViewModel {
    weak var delegate: FeaturesFlowDelegate?
    let dataSource: FeaturesDataSource

    /// Caching Manager
    let manager = CachingManager.shared

    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
    }

    /// Fetch Features
    func fetchFeatures(apiUrl: String?) {
        // Check for cache data
        if let json = manager.getData(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            if let jsonPetitions = try? decoder.decode(FeaturesDataModel.self, from: json) {
                if let features = jsonPetitions.features {
                    // Call Success Delegate with mention of data available but its not remote
                    delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
                } else {
                    delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: false)
                    logger.error("Failed parsed local data")
                }
            }
        } else {
            delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: false)
            logger.error("Failed load local data")
        }

        guard let apiUrl = apiUrl else { return }
        dataSource.fetchFeatures(apiUrl: apiUrl) { [weak self] result in
            switch result {
            case .success(let data):
                self?.prepareFeaturesData(data: data)
            case .failure(let error):
                self?.delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: true)
                logger.error("Failed get features: \(error.localizedDescription)")
            }
        }
    }

    /// Cache API Response and push success event
    func prepareFeaturesData(data: Data) {
        manager.putData(fileName: Constants.featureCache, content: data)

        // Call Success Delegate with mention of data available with remote
        let decoder = JSONDecoder()

        if let jsonPetitions = try? decoder.decode(FeaturesDataModel.self, from: data) {
            guard let features = jsonPetitions.features else {
                delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: true)
                return
            }
            delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
        }
    }
}
