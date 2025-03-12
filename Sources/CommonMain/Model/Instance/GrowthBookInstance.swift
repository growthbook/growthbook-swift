import Foundation

/// A struct representing a GrowthBook instance.
public struct GrowthBookInstance: Sendable, Equatable {
    /// Instance API host URL.
    public var apiHostURL: URL
    /// A client key.
    public var clientKey: String
    /// Payload type for the instance.
    public var payloadType: PayloadType
    /// Refresh policy for the instance.
    public var refreshPolicy: RefreshPolicy

    /// Initializes a new `GrowthBookInstance` instance.
    /// - Parameters:
    ///  - apiHostURL: Instance API host URL.
    /// - clientKey: A client key.
    /// - payloadType: Payload type for the instance.
    /// - refreshPolicy: Refresh policy for the instance.
    public init(apiHostURL: URL, clientKey: String, payloadType: PayloadType, refreshPolicy: RefreshPolicy) {
        self.apiHostURL = apiHostURL
        self.clientKey = clientKey
        self.payloadType = payloadType
        self.refreshPolicy = refreshPolicy
    }
}

extension GrowthBookInstance {
    /// An URL to the GrowthBook API.
    public var apiURL: URL {
        apiHostURL.appendingPathComponent("api", isDirectory: true)
    }

    /// An URL to fetch features.
    public var featuresURL: URL {
        apiURL
            .appendingPathComponent("features", isDirectory: true)
            .appendingPathComponent(clientKey, isDirectory: false)
    }

    /// An URL to fetch remote evaluated features.
    public var remoteEvalURL: URL {
        apiURL
            .appendingPathComponent("eval", isDirectory: true)
            .appendingPathComponent(clientKey, isDirectory: false)
    }

    /// An URL to subscribe to server-side events.
    public var serverSideEventsURL: URL {
        apiHostURL
            .appendingPathComponent("sub", isDirectory: true)
            .appendingPathComponent(clientKey, isDirectory: false)
    }
}
