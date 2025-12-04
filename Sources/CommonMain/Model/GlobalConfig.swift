import Foundation

/// Immutable global configuration for GrowthBook SDK.
///
/// This class holds all configuration values that do not change after initialization,
/// such as API endpoints, client keys, and SDK-wide settings.
///
/// **Key Characteristics:**
/// - All properties are `let` (immutable)
/// - Created once during SDK initialization
/// - Shared across all evaluations
///
/// **Example:**
/// ```swift
/// let config = GlobalConfig(
///     apiHost: "https://api.growthbook.io",
///     clientKey: "sdk-abc123",
///     encryptionKey: "enc-key",
///     isEnabled: true,
///     isQaMode: false,
///     backgroundSync: true,
///     remoteEval: false,
///     trackingClosure: { experiment, result in
///         // Track experiment exposure
///     },
///     stickyBucketService: stickyBucketService
/// )
/// ```
@objc public class GlobalConfig: NSObject {
  /// Your api host
  public let apiHost: String?
  /// Unique client key
  public let clientKey: String?
  /// Encryption key for encrypted features.
  public let encryptionKey: String?
  /// Switch to globally disable all experiments. Default true.
  public let isEnabled: Bool
  /// If true, random assignment is disabled and only explicitly forced variations are used.
  public let isQaMode: Bool
  /// Disable background streaming connection
  public let backgroundSync: Bool
  /// Enable to use remote evaluation
  public let remoteEval: Bool
  /// A function that takes experiment and result as arguments.
  public let trackingClosure: (Experiment, ExperimentResult) -> Void
  /// Sticky bucketing is enabled if stickyBucketService is available
  public let stickyBucketService: StickyBucketServiceProtocol?

  @objc public init(apiHost: String?,
    clientKey: String?,
    encryptionKey: String?,
    isEnabled: Bool,
    isQaMode: Bool,
    backgroundSync: Bool = false,
    remoteEval: Bool = false,
    trackingClosure: @escaping (Experiment, ExperimentResult) -> Void,
    stickyBucketService: StickyBucketServiceProtocol? = nil) {
    self.apiHost = apiHost
    self.clientKey = clientKey
    self.encryptionKey = encryptionKey
    self.isEnabled = isEnabled
    self.isQaMode = isQaMode
    self.backgroundSync = backgroundSync
    self.remoteEval = remoteEval
    self.trackingClosure = trackingClosure
    self.stickyBucketService = stickyBucketService
  }
}