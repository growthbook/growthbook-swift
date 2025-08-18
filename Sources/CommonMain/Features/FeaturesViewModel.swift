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
    /// Caching Manager
    let manager: CachingLayer
    /// SSE Handler for background sync
    internal var sseHandler: SSEHandler?
        
    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource, cachingManager: CachingLayer) {
        self.delegate = delegate
        self.dataSource = dataSource
        self.manager = cachingManager
        self.fetchCachedFeatures()
    }
    
    func connectBackgroundSync(sseUrl: String) {
        guard let url = URL(string: sseUrl) else { return }
        
        // Disconnect existing connection if any
        sseHandler?.disconnect()
        
        let streamingUpdate = SSEHandler(url: url)
        sseHandler = streamingUpdate
        
        streamingUpdate.addEventListener(event: "features") { [weak self] id, event, data in
            guard let jsonData = data?.data(using: .utf8) else { return }
            self?.prepareFeaturesData(data: jsonData)
        }
        streamingUpdate.connect()
        
        streamingUpdate.onDissconnect { [weak streamingUpdate] _, shouldReconnect, _ in
            if let shouldReconnect = shouldReconnect, shouldReconnect {
                streamingUpdate?.connect()
            }
        }
    }
    
    deinit {
        sseHandler?.disconnect()
    }
    
    private func fetchCachedFeatures(logging: Bool = false) {
        // Check for cache data
        if let data = manager.getContent(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            if let encryptedString = String(data: data, encoding: .utf8), let encryptionKey, !encryptionKey.isEmpty {
                let crypto: CryptoProtocol = Crypto()
                if let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                    delegate?.featuresFetchedSuccessfully(features: features, isRemote: false)
                } else {
                    delegate?.featuresFetchFailed(error: .failedParsedEncryptedData, isRemote: false)
                    if logging { logger.error("Failed get features from cached encrypted features") }
                }
            } else if let features = try? decoder.decode(Features.self, from: data) {
                // Call Success Delegate with mention of data available but its not remote
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: false)
            } else {
                delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: false)
                if logging { logger.error("Failed parse local data") }
            }
        } else {
            delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: false)
            if logging { logger.info("Cache directory is empty. Nothing to fetch.") }
        }
    }

    /// Fetch Features
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil) {
        // Check for cache data
        fetchCachedFeatures(logging: true)
        
        if let apiUrl = apiUrl {
            if remoteEval {
                dataSource.fetchRemoteEval(apiUrl: apiUrl, params: payload) { result in
                    switch result {
                    case .success(let data):
                        self.prepareFeaturesData(data: data)
                    case .failure(let error):
                        self.delegate?.featuresFetchFailed(error: .init(code: .failedToFetchData, underlying: error), isRemote: true)
                        logger.error("Failed get features: \(error.localizedDescription)")
                    }
                }
            } else {
                dataSource.fetchFeatures(apiUrl: apiUrl) { result in
                    switch result {
                    case .success(let data):
                        self.prepareFeaturesData(data: data)
                    case .failure(let error):
                        self.delegate?.featuresFetchFailed(error: .init(code: .failedToFetchData, underlying: error), isRemote: true)
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
                        if let featureData = encryptedString.data(using: .utf8) {
                            manager.saveContent(fileName: Constants.featureCache, content: featureData)
                        } else {
                            logger.error("Failed encode features")
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
                if let featureData = try? JSONEncoder().encode(features) {
                    manager.saveContent(fileName: Constants.featureCache, content: featureData)
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
                    if let encryptedSavedGroups = encryptedSavedGroups.data(using: .utf8) {
                        manager.saveContent(fileName: Constants.savedGroupsCache, content: encryptedSavedGroups)
                    } else {
                        logger.error("Failed encode saved groups")
                    }
                    delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: true)
                } else {
                    delegate?.savedGroupsFetchFailed(error: .failedEncryptedSavedGroups, isRemote: true)
                    logger.error("Failed get saved groups from encrypted saved groups")
                    return
                }
            } else if let savedGroups = jsonPetitions.savedGroups {
                if let savedGroupsData = try? JSONEncoder().encode(savedGroups) {
                    manager.saveContent(fileName: Constants.savedGroupsCache, content: savedGroupsData)
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
