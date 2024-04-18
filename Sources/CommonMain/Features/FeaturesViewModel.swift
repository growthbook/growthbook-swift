import Foundation

/// Interface for Feature API Completion Events
protocol FeaturesFlowDelegate: AnyObject {
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool)
    func featuresAPIModelSuccessfully(model: FeaturesDataModel)
    func featuresFetchFailed(error: SDKError, isRemote: Bool)
}

/// View Model for Features
class FeaturesViewModel {
    weak var delegate: FeaturesFlowDelegate?
    let dataSource: FeaturesDataSource
    var encryptionKey: String?
    /// Caching Manager
    let manager = CachingManager.shared
        
    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource) {
        self.delegate = delegate
        self.dataSource = dataSource
        self.fetchFeatures(apiUrl: nil)
    }
    
    func connectBackgroundSync(sseUrl: String) {
        guard let url = URL(string: sseUrl) else { return }
        let streamingUpdate = SSEHandler(url: url)
        streamingUpdate.addEventListener(event: "features") { [weak self] id, event, data in
            guard let jsonData = data?.data(using: .utf8) else { return }
            self?.prepareFeaturesData(data: jsonData)
        }
        streamingUpdate.connect()
    }

    /// Fetch Features
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil) {
        // Check for cache data
        if let json = manager.getData(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            if let features = try? decoder.decode(Features.self, from: json) {
                // Call Success Delegate with mention of data available but its not remote
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: false)
            } else {
                delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: false)
                logger.error("Failed parse local data")
            }
        } else {
            delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: false)
            logger.error("Failed load local data")
        }
        
        if let apiUrl = apiUrl {
            if remoteEval {
                dataSource.fetchRemoteEval(apiUrl: apiUrl, params: payload) { result in
                    switch result {
                    case .success(let data):
                        self.prepareFeaturesData(data: data)
                    case .failure(let error):
                        self.delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: true)
                        logger.error("Failed get features: \(error.localizedDescription)")
                    }
                }
            } else {
                dataSource.fetchFeatures(apiUrl: apiUrl) { result in
                    switch result {
                    case .success(let data):
                        self.prepareFeaturesData(data: data)
                    case .failure(let error):
                        self.delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: true)
                        logger.error("Failed get features: \(error.localizedDescription)")
                    }
                }
            }
        }
    }

    /// Cache API Response and push success event
    func prepareFeaturesData(data: Data) {
        // Call Success Delegate with mention of data available with remote
        let decoder = JSONDecoder()
        if let jsonPetitions = try? decoder.decode(FeaturesDataModel.self, from: data) {
            delegate?.featuresAPIModelSuccessfully(model: jsonPetitions)
            if let features = jsonPetitions.features, !features.isEmpty {
                if let featureData = try? JSONEncoder().encode(features) {
                    manager.putData(fileName: Constants.featureCache, content: featureData)
                }
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
            } else {
                if let encryptedString = jsonPetitions.encryptedFeatures, !encryptedString.isEmpty  {
                    if let encryptionKey = encryptionKey, !encryptionKey.isEmpty {
                        let crypto: CryptoProtocol = Crypto()
                        guard let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) else { return }
                        
                        if let featureData = try? JSONEncoder().encode(features) {
                            manager.putData(fileName: Constants.featureCache, content: featureData)
                        }
                        delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
                    } else {
                        delegate?.featuresFetchFailed(error: .failedMissingKey, isRemote: true)
                        return
                    }
                } else {
                    delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: true)
                    return
                }
            }
        }
    }
}
