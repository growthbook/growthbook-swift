import Foundation

/// Interface for Feature API Completion Events
protocol FeaturesFlowDelegate: AnyObject {
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool)
    func featuresAPIModelSuccessfully(model: FeaturesDataModel)
    func featuresFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool)
}

/// View Model for Features
class FeaturesViewModel {
    weak var delegate: FeaturesFlowDelegate?
    let dataSource: FeaturesDataSource
    var encryptionKey: String?
    private let featuresCache: FeaturesCacheInterface
    private let savedGroupsCache: SavedGroupsCacheInterface

    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource, featuresCache: FeaturesCacheInterface, savedGroupsCache: SavedGroupsCacheInterface) {
        self.delegate = delegate
        self.dataSource = dataSource
        self.featuresCache = featuresCache
        self.savedGroupsCache = savedGroupsCache
        self.fetchCachedFeatures()
    }

    func connectBackgroundSync(sseUrl: String) {
        guard let url = URL(string: sseUrl) else { return }
        let streamingUpdate = SSEHandler(url: url)
        streamingUpdate.addEventListener(event: "features") { [weak self] id, event, data in
            guard let jsonData = data?.data(using: .utf8) else { return }
            self?.prepareFeaturesData(data: jsonData)
        }
        streamingUpdate.connect()
        
        streamingUpdate.onDisconnect { _, shouldReconnect, _ in
            if let shouldReconnect = shouldReconnect, shouldReconnect {
                streamingUpdate.connect()
            }
        }
    }

    @discardableResult
    private func fetchCachedFeatures() -> Features? {
        // Check for cache data
        do {
            let features = try featuresCache.features() ?? [:]
            delegate?.featuresFetchedSuccessfully(features: features, isRemote: false)
            return features
        } catch let error as SDKError {
            delegate?.featuresFetchFailed(error: error, isRemote: false)
        } catch {
            delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: false)
        }
        return .none
    }

    /// Fetch Features
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil) {
        // Check for cache data
        _ = fetchCachedFeatures()

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
        } else {
            delegate?.featuresFetchFailed(error: .failedMissingKey, isRemote: true)
            logger.error("Failed get api URL")
        }
    }

    /// Cache API Response and push success event
    func prepareFeaturesData(data: Data) {
        // Call Success Delegate with mention of data available with remote
        
        let decoder = JSONDecoder()
        if let jsonPetitions = try? decoder.decode(FeaturesDataModel.self, from: data) {
            delegate?.featuresAPIModelSuccessfully(model: jsonPetitions)
            if let encryptedString = jsonPetitions.encryptedFeatures {
                if let encryptionKey = encryptionKey, !encryptionKey.isEmpty {
                    let crypto: CryptoProtocol = Crypto()
                    if let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                        do {
                            try featuresCache.updateFeatures(features)
                        } catch {
                            logger.error("Failed to update cache for features \(error)")
                        }
                        delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
                    } else {
                        delegate?.featuresFetchFailed(error: .failedEncryptedFeatures, isRemote: true)
                        logger.error("Failed get features from encrypted features")
                        return
                    }
                } else {
                    delegate?.featuresFetchFailed(error: .failedMissingKey, isRemote: true)
                    logger.error("Failed get encryption key or it's empty")
                    return
                }
            } else if let features = jsonPetitions.features {
                do {
                    try featuresCache.updateFeatures(features)
                } catch {
                    logger.error("Failed to update features \(error)")
                }
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: true)
            } else {
                delegate?.featuresFetchFailed(error: .failedMissingKey, isRemote: true)
                logger.error("Failed get encrypted features or it's empty")
                return
            }
            
            if let encryptedSavedGroups = jsonPetitions.encryptedSavedGroups, !encryptedSavedGroups.isEmpty, let encryptionKey = encryptionKey, !encryptionKey.isEmpty {
                let crypto = Crypto()
                if let savedGroups = crypto.getSavedGroupsFromEncryptedFeatures(encryptedString: encryptedSavedGroups, encryptionKey: encryptionKey) {
                    do {
                        try savedGroupsCache.updateSavedGroups(savedGroups)
                    } catch {
                        logger.error("Failed to update cache for saved groups \(error)")
                    }
                    delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: true)
                } else {
                    delegate?.savedGroupsFetchFailed(error: .failedEncryptedSavedGroups, isRemote: true)
                    logger.error("Failed get saved groups from encrypted saved groups")
                    return
                }
            } else if let savedGroups = jsonPetitions.savedGroups {
                do {
                    try savedGroupsCache.updateSavedGroups(savedGroups)
                } catch {
                    logger.error("Failed to update cache for saved groups \(error)")
                }
                delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: true)
            }
        } else {
            delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: true)
            logger.error("Failed get features data model")
            return
        }
    }
        
}
