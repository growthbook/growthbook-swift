import Foundation

/// Read-only snapshot of the feature-cache state.
///
/// Exposed via `GrowthBookSDK.cacheMetadata` so applications can monitor refresh
/// behaviour, display diagnostic information, and decide when to force a refresh.
/// The values reflect the current session and are recomputed on each access.
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
