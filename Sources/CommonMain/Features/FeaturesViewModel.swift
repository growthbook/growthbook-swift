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
    let fallbackFeatures: Features?
    
    private let ttlSeconds: Int
    private var expiresAt: TimeInterval?
    
    /// SSE Handler for background sync
    internal var sseHandler: SSEHandler?
    private var streamingUpdate: SSEHandler?
    private let retryHandler = NetworkRetryHandler()
        
    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource, cachingManager: CachingLayer, ttlSeconds: Int, fallbackFeatures: Features? = nil) {

        self.delegate = delegate
        self.dataSource = dataSource
        self.manager = cachingManager
        self.ttlSeconds=ttlSeconds
        self.fallbackFeatures=fallbackFeatures
    }
    
    
    private func isCacheExpired() -> Bool {
        guard let expiresAt = expiresAt else {
            return true
        }
        return Date().timeIntervalSince1970 >= expiresAt
    }
    
    private func refreshExpiresAt() {
        expiresAt = Date().timeIntervalSince1970 + Double(ttlSeconds)
    }
        
    func connectBackgroundSync(sseUrl: String, apiUrl: String?) {
           guard let url = URL(string: sseUrl) else { return }

           let handler = SSEHandler(url: url)
           self.streamingUpdate = handler

           handler.addEventListener(event: "features") { [weak self] id, event, data in
               guard let jsonData = data?.data(using: .utf8) else { return }
               self?.prepareFeaturesData(data: jsonData)
           }

           handler.onDissconnect { [weak self] _, shouldReconnect, _ in
               guard let self = self else { return }
               if shouldReconnect == true {
                   self.retryHandler.retryWhenOnline {
                       self.streamingUpdate?.connect()
                   }
               }
           }

           retryHandler.retryWhenOnline {
               logger.info("Connection established, fetching features from remote")
               self.fetchFeatures(apiUrl: apiUrl)
               handler.connect()
           }
       }
    
    deinit {
        sseHandler?.disconnect()
    }
       
    
    private func fetchCachedFeatures() -> Features? {
        if let json = manager.getContent(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            if let features = try? decoder.decode(Features.self, from: json) {
                return features
            } else {
                logger.error("Failed to parse cached features")
                return nil
            }
        } else {
            logger.warning("No cached features found")
            return nil
        }
    }


    /// Fetch Features
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil) {
        let cached = fetchCachedFeatures()

        if let cached, !isCacheExpired() {
            delegate?.featuresFetchedSuccessfully(features: cached, isRemote: false)
            return
        }

        guard let apiUrl else {
            useCachedOrFallback(cached)
            return
        }

        dataSource.fetchFeatures(apiUrl: apiUrl) { result in
            switch result {
            case .success(let data):
                self.prepareFeaturesData(data: data)
            case .failure(let error):
                logger.error("Failed fetching from API: \(error.localizedDescription)")
                self.useCachedOrFallback(cached)
            }
        }

        if remoteEval {
            dataSource.fetchRemoteEval(apiUrl: apiUrl, params: payload) { result in
                switch result {
                case .success(let data):
                    self.prepareFeaturesData(data: data)
                case .failure(let error):
                    self.delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: true)
                    logger.error("Remote eval failed: \(error.localizedDescription)")
                }
            }
        }
    }

    
    private func useCachedOrFallback(_ cached: Features?) {
        if let cached {
            logger.info("Using expired cache as fallback")
            delegate?.featuresFetchedSuccessfully(features: cached, isRemote: false)
        } else if let fallback = fallbackFeatures {
            logger.info("Using fallback features")
            delegate?.featuresFetchedSuccessfully(features: fallback, isRemote: false)
        } else {
            logger.warning("No cache or fallback features available")
            delegate?.featuresFetchFailed(error: .failedToLoadData, isRemote: false)
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
                        if let featureData = try? JSONEncoder().encode(features) {
                            manager.saveContent(fileName: Constants.featureCache, content: featureData)
                            refreshExpiresAt()
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
                    refreshExpiresAt()
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
