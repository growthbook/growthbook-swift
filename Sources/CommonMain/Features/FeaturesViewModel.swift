import Foundation

/// Interface for Feature API Completion Events
protocol FeaturesFlowDelegate: AnyObject {
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool)
    func featuresAPIModelSuccessfully(model: FeaturesDataModel)
    func featuresFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool)
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool)
    func contextualBanditsFetchFailed(error: SDKError, isRemote: Bool)
    func contextualBanditsFetchedSuccessfully(contextualBandits: JSON, isRemote: Bool)
    /// A payload arrived that carries no bandit definitions at all — neither plain nor encrypted.
    func contextualBanditsCleared(isRemote: Bool)
    /// A payload arrived that carries no saved groups at all — neither plain nor encrypted.
    func savedGroupsCleared(isRemote: Bool)
    func featuresUpdateIsComplete(error: SDKError?, isRemote: Bool)
    /// Runs `body` under the lock that guards the delegate's state, so a check and the update it
    /// guards can't interleave with other updates.
    func performLocked(_ body: () -> Void)
}

extension FeaturesFlowDelegate {
    /// Default no-op: only GrowthBookSDK owns bandit state.
    func contextualBanditsCleared(isRemote: Bool) {}
    /// Default no-op: only GrowthBookSDK owns saved-group state.
    func savedGroupsCleared(isRemote: Bool) {}
    func performLocked(_ body: () -> Void) { body() }
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
    /// Numbers remote-eval requests, so a reply for older inputs never replaces a newer one's.
    /// Read and written only inside `delegate.performLocked`.
    private var latestRemoteEvalRequest = 0
    
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
    
    /// - Parameter headers: headers for the streaming host. The SDK's own `Accept`,
    ///   `Cache-Control` and `Last-Event-Id` are applied after these, so they cannot be overridden.
    func connectBackgroundSync(sseUrl: String, headers: [String: String] = [:]) {
        guard let url = URL(string: sseUrl) else { return }
        
        // Disconnect existing connection if any
        sseHandler?.disconnect()
        
        let streamingUpdate = SSEHandler(url: url, headers: headers)
        sseHandler = streamingUpdate
        
        streamingUpdate.addEventListener(event: "features") { [weak self] id, event, data in
            guard let data = data, !data.isEmpty,
                  let jsonData = data.data(using: .utf8) else { return }
            self?.prepareFeaturesData(data: jsonData)
        }
        streamingUpdate.connect()
        
        // The handler owns reconnecting, so there is nothing to do while it still intends to come
        // back. Once it gives up, streaming is over for this instance and nothing else reports it,
        // which would otherwise leave features silently frozen — so log that much. A cancelled task
        // is our own `disconnect()` above (or in deinit) and is not a failure.
        streamingUpdate.onDisconnect { statusCode, willReconnect, error in
            guard willReconnect != true else { return }
            let cancelled = error?.domain == NSURLErrorDomain && error?.code == NSURLErrorCancelled
            guard !cancelled else { return }

            let reason = error?.localizedDescription ?? statusCode.map { "HTTP \($0)" } ?? "unknown reason"
            logger.error("Streaming stopped and will not reconnect: \(reason)")
        }
    }
    
    /// Replaces the streaming host headers on the live connection, so the next reconnect sends
    /// them — a rotated token reaches the stream without restarting the SDK. The open connection
    /// keeps the headers it was made with.
    func updateStreamingHeaders(_ headers: [String: String]) {
        sseHandler?.headers = headers
    }

    deinit {
        sseHandler?.disconnect()
    }

    /// Reads the cache. `isRemote` is passed to the features callbacks only: saved groups and
    /// bandits are always reported as cached, even after a 304 or failed fetch, so stableSession's
    /// guards for cached sections apply.
    @discardableResult
    private func fetchCachedFeatures(logging: Bool = false, isRemote: Bool = false) -> SDKError? {
        var occurredError: SDKError? = nil
        // Check for cache data
        if let data = manager.getContent(fileName: Constants.featureCache) {
            let decoder = JSONDecoder()
            // The network and preload paths cache features already decrypted, so plain JSON comes
            // first even with an encryption key; an encrypted string is still read for older caches.
            if let features = try? decoder.decode(Features.self, from: data) {
                // Call Success Delegate with mention of data available but its not remote
                delegate?.featuresFetchedSuccessfully(features: features, isRemote: isRemote)
            } else if let encryptedString = String(data: data, encoding: .utf8), let encryptionKey, !encryptionKey.isEmpty {
                let crypto: CryptoProtocol = Crypto()
                if let features = crypto.getFeaturesFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                    delegate?.featuresFetchedSuccessfully(features: features, isRemote: isRemote)
                } else {
                    let error = SDKError.failedParsedEncryptedData
                    delegate?.featuresFetchFailed(error: error, isRemote: isRemote)
                    if logging { logger.error("Failed get features from cached encrypted features") }
                    return error
                }
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

        // Saved groups and bandits are cached as plain JSON when the payload had them unencrypted,
        // even with an encryption key, so plain JSON comes first here as for the features. Only a
        // JSON object is accepted: the encrypted form isn't JSON, and a scalar from a corrupt file
        // would make every `$notInGroup` match. An empty file means the payload had none, which is
        // reported like a payload without them so stableSession locks that in.
        if let savedGroupsData = manager.getContent(fileName: Constants.savedGroupsCache) {
            if savedGroupsData.isEmpty {
                delegate?.savedGroupsCleared(isRemote: false)
            } else if let savedGroups = try? JSONDecoder().decode(JSON.self, from: savedGroupsData),
                      savedGroups.type == .dictionary {
                delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: false)
            } else if let encryptionKey, !encryptionKey.isEmpty,
                      let encryptedString = String(data: savedGroupsData, encoding: .utf8),
                      let savedGroups = Crypto().getSavedGroupsFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: false)
            }
        }

        if let contextualBanditsData = manager.getContent(fileName: Constants.contextualBanditsCache) {
            if contextualBanditsData.isEmpty {
                delegate?.contextualBanditsCleared(isRemote: false)
            } else if let contextualBandits = try? JSONDecoder().decode(JSON.self, from: contextualBanditsData),
                      contextualBandits.type == .dictionary {
                delegate?.contextualBanditsFetchedSuccessfully(contextualBandits: contextualBandits, isRemote: false)
            } else if let encryptionKey, !encryptionKey.isEmpty,
                      let encryptedString = String(data: contextualBanditsData, encoding: .utf8),
                      let contextualBandits = Crypto().getContextualBanditsFromEncryptedFeatures(encryptedString: encryptedString, encryptionKey: encryptionKey) {
                delegate?.contextualBanditsFetchedSuccessfully(contextualBandits: contextualBandits, isRemote: false)
            }
        }
        return occurredError
    }
    
    
    /// Fetch Features
    /// - Parameter force: fetch even while the cached features are fresh. Remote-eval results
    ///   depend on the request's attributes and forced values, so a change to those must refetch.
    func fetchFeatures(apiUrl: String?, remoteEval: Bool = false, payload: RemoteEvalParams? = nil, force: Bool = false) {
        // Check for cache data. A forced fetch skips it: the in-memory state is already current,
        // and the reply replaces it.
        if !force {
            fetchCachedFeatures(logging: true)
        }
        guard let apiUrl else {
            delegate?.featuresUpdateIsComplete(error: .invalidAPIURL, isRemote: false)
            return
        }
        guard force || isCacheExpired() else {
            delegate?.featuresUpdateIsComplete(error: nil, isRemote: true)
            return
        }

        if remoteEval {
            var request = 0
            performLocked {
                latestRemoteEvalRequest += 1
                request = latestRemoteEvalRequest
            }
            dataSource.fetchRemoteEval(apiUrl: apiUrl, params: payload) { [request] result in
                // Replies can arrive out of order; only the newest request's inputs are current.
                // Only the check runs under the lock, so evaluations on other threads don't wait
                // for the reply to be decoded and cached. A superseded reply is dropped silently:
                // reporting it would tell refreshHandler about a refresh that applied nothing.
                var isCurrent = false
                self.performLocked { isCurrent = request == self.latestRemoteEvalRequest }
                guard isCurrent else { return }
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
    
    private func performLocked(_ body: () -> Void) {
        if let delegate { delegate.performLocked(body) } else { body() }
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
            
            // Encrypted groups that can't be opened are an error, not a payload without groups:
            // clearing them would make every `$notInGroup` match.
            if let encryptedSavedGroups = jsonPetitions.encryptedSavedGroups, !encryptedSavedGroups.isEmpty {
                let crypto = Crypto()
                if let encryptionKey, !encryptionKey.isEmpty,
                   let savedGroups = crypto.getSavedGroupsFromEncryptedFeatures(encryptedString: encryptedSavedGroups, encryptionKey: encryptionKey) {
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
                    // No return: the features are already applied, so the bandits still need theirs
                    logger.error("Failed get saved groups from encrypted saved groups")
                }
            } else if let savedGroups = jsonPetitions.savedGroups {
                if let savedGroupsData = try? JSONEncoder().encode(savedGroups) {
                    manager.saveContent(fileName: Constants.savedGroupsCache, content: savedGroupsData)
                }
                delegate?.savedGroupsFetchedSuccessfully(savedGroups: savedGroups, isRemote: true)
            } else {
                // The payload carries no saved groups. Clear them like the bandits below, so a later
                // launch doesn't pair these features with an earlier payload's groups.
                manager.saveContent(fileName: Constants.savedGroupsCache, content: Data())
                delegate?.savedGroupsCleared(isRemote: true)
            }

            if let encryptedContextualBandits = jsonPetitions.encryptedContextualBandits, !encryptedContextualBandits.isEmpty {
                let crypto = Crypto()
                if let encryptionKey, !encryptionKey.isEmpty,
                   let contextualBandits = crypto.getContextualBanditsFromEncryptedFeatures(encryptedString: encryptedContextualBandits, encryptionKey: encryptionKey) {
                    if let encryptedContextualBanditsData = encryptedContextualBandits.data(using: .utf8) {
                        manager.saveContent(fileName: Constants.contextualBanditsCache, content: encryptedContextualBanditsData)
                    } else {
                        logger.error("Failed encode contextual bandits")
                    }
                    delegate?.contextualBanditsFetchedSuccessfully(contextualBandits: contextualBandits, isRemote: true)
                } else {
                    let error: SDKError = .failedEncryptedContextualBandits
                    delegate?.contextualBanditsFetchFailed(error: error, isRemote: true)
                    occurredError = error
                    logger.error("Failed get contextual bandits from encrypted contextual bandits")
                    return
                }
            } else if let contextualBandits = jsonPetitions.contextualBandits {
                if let contextualBanditsData = try? JSONEncoder().encode(contextualBandits) {
                    manager.saveContent(fileName: Constants.contextualBanditsCache, content: contextualBanditsData)
                }
                delegate?.contextualBanditsFetchedSuccessfully(contextualBandits: contextualBandits, isRemote: true)
            } else {
                // The payload carries no bandit definitions. Without this branch a previously cached
                // definition would survive both in memory and on disk, and rules would keep bucketing
                // on stale weights and a stale banditVersion instead of falling back to the aggregate
                // weights, which is the documented behaviour for a missing reference.
                manager.saveContent(fileName: Constants.contextualBanditsCache, content: Data())
                delegate?.contextualBanditsCleared(isRemote: true)
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
