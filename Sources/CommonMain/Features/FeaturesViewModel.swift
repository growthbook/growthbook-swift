import Foundation

/// Interface for Feature API Completion Events
protocol FeaturesFlowDelegate: AnyObject {
    func featuresAPIModelSuccessfully(model: DecryptedFeaturesDataModel, fetchType: GrowthBookFeaturesFetchResult.FetchType)

    func featuresFetchFailed(error: Error, fetchType: GrowthBookFeaturesFetchResult.FetchType)
}

/// View Model for Features
final class FeaturesViewModel: Sendable {
    private class MutableState {
        weak var delegate: FeaturesFlowDelegate?

        init(delegate: FeaturesFlowDelegate? = nil) {
            self.delegate = delegate
        }
    }

    private let mutableState: Protected<MutableState>

    var delegate: FeaturesFlowDelegate? {
        get { mutableState.read(\.delegate) }
        set { mutableState.write(\.delegate, newValue) }
    }

    private let featuresCache: FeaturesCacheInterface
    private let savedGroupsCache: SavedGroupsCacheInterface

    private let featuresModelProvider: FeaturesModelProviderInterface?
    private let featuresModelFetcher: FeaturesModelFetcherInterface

    init(
        delegate: FeaturesFlowDelegate,
        featuresCache: FeaturesCacheInterface,
        savedGroupsCache: SavedGroupsCacheInterface,
        featuresModelProvider: FeaturesModelProviderInterface?,
        featuresModelFetcher: FeaturesModelFetcherInterface
    )
    {
        self.mutableState = .init(.init(delegate: delegate))
        self.featuresCache = featuresCache
        self.savedGroupsCache = savedGroupsCache
        self.featuresModelProvider = featuresModelProvider
        self.featuresModelFetcher = featuresModelFetcher

        self.initialize()
    }

    deinit {
        featuresModelProvider?.unsubscribeFromFeaturesUpdates()
    }

    private func initialize() {
        fetchCachedFeatures()
        fetchRemoteFeatures()
    }

    private func fetchCachedFeatures() {
        // Notifying delegate about initial fetch results, so the context will be valid.
        // As for the full initialization with remote - it's on the side of the consumer
        // to decide if they can treat initial cached context
        do {
            // If there is no cache - don't notify the delegate.
            guard let features = try featuresCache.features(), let savedGroups = try savedGroupsCache.savedGroups() else { return }
            notifyDelegateAboutFetchResult(.success(.init(features: features, savedGroups: savedGroups, experiments: [])), fetchType: .local)
        } catch {
            notifyDelegateAboutFetchResult(.failure(error), fetchType: .local)
        }
    }

    private func notifyDelegateAboutFetchResult(
        _ result: Result<DecryptedFeaturesDataModel, any Error>,
        fetchType: GrowthBookFeaturesFetchResult.FetchType
    )
    {
        guard let delegate else { return }

        switch result {
        case let .success(model):
            delegate.featuresAPIModelSuccessfully(model: model, fetchType: fetchType)
        case let .failure(error):
            delegate.featuresFetchFailed(error: error, fetchType: fetchType)
        }
    }

    private func updateCache(with response: DecryptedFeaturesDataModel) {
        try? featuresCache.updateFeatures(response.features)
        try? savedGroupsCache.updateSavedGroups(response.savedGroups)
    }

    private func handleFeaturesFetchResult(_ result: Result<DecryptedFeaturesDataModel, any Error>, fetchType: GrowthBookFeaturesFetchResult.FetchType) {
        switch result {
        case let .success(response):
            updateCache(with: response)
        case .failure:
            break
        }

        self.notifyDelegateAboutFetchResult(result, fetchType: fetchType)
    }

    func fetchFeaturesOnce() {
        featuresModelFetcher.fetchFeatures { [weak self] (result: Result<FeaturesModelResponse, any Error>) in
            guard let self else { return }

            self.handleFeaturesFetchResult(result.map(\.decryptedFeaturesDataModel), fetchType: .remoteForced)
        }
    }

    private func fetchRemoteFeatures() {
        featuresModelFetcher.fetchFeatures { [weak self] (result: Result<FeaturesModelResponse, any Error>) in
            guard let self else { return }

            self.handleFeaturesFetchResult(result.map(\.decryptedFeaturesDataModel), fetchType: .initialRemote)

            self.subscribeToFeaturesUpdates()
        }
    }

    private func subscribeToFeaturesUpdates() {
        featuresModelProvider?.delegate = self
        featuresModelProvider?.subscribeToFeaturesUpdates()
    }
}

extension FeaturesViewModel: FeaturesModelProviderDelegate {
    func featuresProvider(_ provider: any FeaturesModelProviderInterface, didUpdate featuresModel: DecryptedFeaturesDataModel) {
        handleFeaturesFetchResult(.success(featuresModel), fetchType: .remoteRefresh)
    }

    func featuresProvider(_ provider: any FeaturesModelProviderInterface, didFailToUpdate error: any Error) {
        handleFeaturesFetchResult(.failure(error), fetchType: .remoteRefresh)
    }
}
