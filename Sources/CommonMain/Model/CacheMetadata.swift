import Foundation

/// Read-only snapshot of the feature-cache state.
///
/// Exposed via `GrowthBookSDK.cacheMetadata` so applications can monitor refresh
/// behaviour, display diagnostic information, and decide when to force a refresh.
/// The values reflect the current session and are recomputed on each access.
///
/// - Important: `lastRefresh`/`expiresAt` track only network refreshes (a `200` fetch
///   or a `304` revalidation) within the current session; they are not persisted to
///   disk. As a result, `lastRefresh` is `nil` and `isExpired` is `true` until the
///   first network refresh completes — including immediately after a cold start that
///   loaded features from the disk cache, and in offline / preloaded-payload mode where
///   no automatic fetch runs. In those cases the SDK may already be serving valid
///   features even though `isExpired` reports `true`, so do not treat `isExpired == true`
///   as "no features available".
public struct CacheMetadata {
    /// Timestamp of the last successful feature refresh (network fetch or `304` revalidation).
    /// `nil` until the first successful refresh in this session.
    public let lastRefresh: Date?
    /// Seconds elapsed since `lastRefresh`, measured at access time.
    /// `nil` when there has been no successful refresh yet.
    public let cacheAge: TimeInterval?
    /// The moment the cached features are considered expired (`lastRefresh + ttl`).
    /// `nil` until the first successful refresh in this session.
    public let expiresAt: Date?
    /// Whether the cache is currently expired. `true` when no refresh has happened yet.
    public let isExpired: Bool
}
