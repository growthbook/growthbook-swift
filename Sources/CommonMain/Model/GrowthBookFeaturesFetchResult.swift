/// Handler for features fetch result.
///
/// It updates back whether cache was refreshed or not
public typealias FeaturesFetchResultHandler = @Sendable (GrowthBookFeaturesFetchResult) -> Void

public struct GrowthBookFeaturesFetchResult: Sendable {

    /// Features fetch type.
    public enum FetchType: Sendable, Equatable {
        /// Initialized with local storage.
        case local

        /// Initial fetch from remote.
        case initialRemote

        /// On GrowthBook attributes change (attribute overrides, forced variations, or refreshCache is caled).
        case remoteForced

        /// Scheduled fetch from remote (Server-Side events or Polling).
        case remoteRefresh
    }

    /// Features fetch type.
    public let type: FetchType

    /// An error if an error occurred during fetch.
    public let error: Error?
}
