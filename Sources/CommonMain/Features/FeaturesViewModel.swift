import Foundation

/// Interface for Feature API Completion Events
protocol FeaturesFlowDelegate: AnyObject {
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool)
    func featuresAPIModelSuccessfully(model: FeaturesDataModel)
    func featuresFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool)
    func featuresUpdateIsComplete(error: SDKError?, isRemote: Bool)
}

/// View Model for Features
class FeaturesViewModel {
    weak var delegate: FeaturesFlowDelegate?
    let dataSource: FeaturesDataSource
    var encryptionKey: String?
    /// Caching Manager
    let manager: CachingLayer
    internal var sseHandler: SSEHandler?
    private let ttlSeconds: Int
    private var expiresAt: TimeInterval?
    
    init(delegate: FeaturesFlowDelegate, dataSource: FeaturesDataSource, cachingManager: CachingLayer, ttlSeconds: Int, preloadedFeatures: Features? = nil) {
        self.delegate = delegate
        self.dataSource = dataSource
        self.manager = cachingManager
        self.ttlSeconds = ttlSeconds
        // Skip the cache read when the caller has already supplied parsed features.
        // This eliminates the disk round-trip that would otherwise occur on every init
        // when features are provided directly to the builder.
        if preloadedFeatures == nil {
            self.fetchCachedFeatures()
        }
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
        
        // The handler owns reconnecting, so there is nothing to do while it still intends to come
        // back. Once it gives up, streaming is over for this instance and nothing else reports it,
        // which would otherwise leave features silently frozen — so log that much. A cancelled task
        // is our own `disconnect()` above (or in deinit) and is not a failure.
        streamingUpdate.onDissconnect { statusCode, willReconnect, error in
            guard willReconnect != true else { return }
            let cancelled = error?.domain == NSURLErrorDomain && error?.code == NSURLErrorCancelled
            guard !cancelled else { return }

            let reason = error?.localizedDescription ?? statusCode.map { "HTTP \($0)" } ?? "unknown reason"
            logger.error("Streaming stopped and will not reconnect: \(reason)")
        }
    }
    
    deinit {
        sseHandler?.disconnect()
    }

    @discardableResult
    private func fetchCachedFeatures(logging: Bool = false, isRemote: Bool = false) -> SDKError? {
        var occurredError: SDKError? = nil
        // Check for cache data
        if let data = manager.getContent(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            if let encryptedString = String(data: data, encoding: .utf8), let encryptionKey, !encryptionKey.isEmpty {
                let crypto: CryptoProtocol = Crypto()
                if let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                    delegate?.featuresFetchedSuccessfully(features: features, isRemote: isRemote)
                } else {
                    let error = SDKError.failedParsedEncryptedData
                    delegate?.featuresFetchFailed(error: error, isRemote: isRemote)
                    if logging { logger.error("Failed get features from cached encrypted features") }
                    return error
                }
            } else if let features = try? decoder.decode(Features.self, from: data) {
                // Call Success Delegate with mention of data available but its not remote
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: isRemote)
            } else {
                let error = SDKError.failedParsedData
                delegate?.featuresFetchFailed(error: error, isRemote: isRemote)
                occurredError = error
                if logging { logger.error("Failed parse local data") }
            }
        } else {
            let error = SDKError.failedToLoadData
            delegate?.featuresFetchFailed(error: error, isRemote: isRemote)
            occurredError = error
            if logging { logger.info("Cache directory is empty. Nothing to fetch.") }
        }

        if let savedGroupsData = manager.getContent(fileName: Constants.savedGroupsCache) {
            if let encryptionKey, !encryptionKey.isEmpty {
                if let encryptedString = String(data: savedGroupsData, encoding: .utf8),
                   let savedGroups = Crypto().getSavedGroupsFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                    delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: isRemote)
                }
            } else if let savedGroups = try? JSONDecoder().decode(JSON.self, from: savedGroupsData) {
                delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: isRemote)
            }
        }
        return occurredError
    }
    
    
    /// Fetch Features
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil) {
        // Check for cache data
        fetchCachedFeatures(logging: true)
        guard let apiUrl else {
            delegate?.featuresUpdateIsComplete(error: .invalidAPIURL, isRemote: false)
            return
        }
        guard isCacheExpired() else {
            delegate?.featuresUpdateIsComplete(error: nil, isRemote: true)
            return
        }

        if remoteEval {
            dataSource.fetchRemoteEval(apiUrl: apiUrl, params: payload) { result in
                switch result {
                case .success(let data):
                    self.prepareFeaturesData(data: data)
                case .failure(let error):
                    logger.error("Failed get features: \(error.localizedDescription)")
                    let error: SDKError = .failedToLoadData
                    self.delegate?.featuresFetchFailed(error: error, isRemote: true)
                    self.delegate?.featuresUpdateIsComplete(error: error, isRemote: true)
                }
            }
        } else {
            dataSource.fetchFeatures(apiUrl: apiUrl) { result in
                switch result {
                case .success(let data):
                    self.prepareFeaturesData(data: data)
                case .failure(let error):
                    if (error as NSError).code == 304 {
                        self.refreshExpiresAt()
                        let fetchCachedFeaturesError = self.fetchCachedFeatures(isRemote: true)
                        self.delegate?.featuresUpdateIsComplete(error: fetchCachedFeaturesError, isRemote: true)
                        return
                    }
                    logger.info("Failed to get features from remote: \(error.localizedDescription)")
                    let sdkError: SDKError = .failedToFetchData(error)
                    self.delegate?.featuresFetchFailed(error: sdkError, isRemote: true)
                    self.fetchCachedFeatures(isRemote: true)
                    self.delegate?.featuresUpdateIsComplete(error: sdkError, isRemote: true)
                }
            }
        }
    }
    
    /// Cache API Response and push success event
    func prepareFeaturesData(data: Data) {
        // Call Success Delegate with mention of data available with remote
        var occurredError: SDKError? = nil
        defer {
            delegate?.featuresUpdateIsComplete(error: occurredError, isRemote: true)
        }

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
                        let error: SDKError = .failedEncryptedFeatures
                        delegate?.featuresFetchFailed(error: error, isRemote: true)
                        occurredError = error
                        logger.error("Failed get features from encrypted features")
                        return
                    }
                } else {
                    let error: SDKError = .failedMissingKey
                    delegate?.featuresFetchFailed(error: error, isRemote: true)
                    occurredError = error
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
                let error: SDKError = .failedMissingKey
                delegate?.featuresFetchFailed(error: error, isRemote: true)
                occurredError = error
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
                    let error: SDKError = .failedEncryptedSavedGroups
                    delegate?.savedGroupsFetchFailed(error: .failedEncryptedSavedGroups, isRemote: true)
                    occurredError = error
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
            let error: SDKError = .failedParsedData
            delegate?.featuresFetchFailed(error: .failedParsedData, isRemote: true)
            occurredError = error
            logger.error("Failed get features data model")
            return
        }
    }
    
}
