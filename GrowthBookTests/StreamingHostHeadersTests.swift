import XCTest

@testable import GrowthBook

/// `streamingHostRequestHeaders` was part of the public API — a builder parameter, a fluent setter and
/// `updateStreamingHostRequestHeaders(_:)` — but the value was stored on the network client and never
/// read: the SSE connection was created without any headers at all. These tests pin the wiring down.
final class StreamingHostHeadersTests: XCTestCase {

    private func makeViewModel() -> FeaturesViewModel {
        FeaturesViewModel(
            delegate: NoopFeaturesFlowDelegate(),
            dataSource: FeaturesDataSource(dispatcher: MockNetworkClient(successResponse: nil, error: nil)),
            cachingManager: CachingManager(apiKey: UUID().uuidString),
            ttlSeconds: 60
        )
    }

    /// A URL that cannot connect: the handler stores its configuration synchronously, so the test
    /// never depends on the connection attempt going anywhere.
    private let deadURL = "http://127.0.0.1:1/sub/key"

    func testStreamingHeadersReachTheSSEConnection() {
        let vm = makeViewModel()

        vm.connectBackgroundSync(sseUrl: deadURL, headers: ["Authorization": "Bearer token", "X-Tenant": "acme"])

        XCTAssertEqual(vm.sseHandler?.headers["Authorization"], "Bearer token",
                       "Headers configured for the streaming host must reach the SSE request")
        XCTAssertEqual(vm.sseHandler?.headers["X-Tenant"], "acme")

        vm.sseHandler?.disconnect()
    }

    func testStreamingConnectionWithoutHeadersStaysEmpty() {
        let vm = makeViewModel()

        vm.connectBackgroundSync(sseUrl: deadURL)

        XCTAssertTrue(vm.sseHandler?.headers.isEmpty ?? false,
                      "Not configuring headers must not invent any")

        vm.sseHandler?.disconnect()
    }

    /// The SDK owns `Accept`, `Cache-Control` and `Last-Event-Id`: a caller must not be able to break
    /// the protocol by overriding them.
    func testSDKManagedHeadersWinOverCallerHeaders() {
        let handler = SSEHandler(
            url: URL(string: deadURL)!,
            headers: [
                "Accept": "text/plain",
                "Cache-Control": "max-age=3600",
                "Last-Event-Id": "caller-value",
                "Authorization": "Bearer token",
            ]
        )

        let configured = handler.sessionConfiguration(lastEventId: "sdk-value").httpAdditionalHeaders as? [String: String]

        XCTAssertEqual(configured?["Accept"], "text/event-stream")
        XCTAssertEqual(configured?["Cache-Control"], "no-cache")
        XCTAssertEqual(configured?["Last-Event-Id"], "sdk-value")
        XCTAssertEqual(configured?["Authorization"], "Bearer token",
                       "Headers the SDK does not manage must survive")
    }

    /// `streamingHost` and the streaming headers are configured through the builder and have to arrive
    /// together: the host decides where the stream goes, the headers decide whether it is allowed in.
    func testBuilderCarriesStreamingHostAndHeaders() {
        let builder = GrowthBookBuilder(
            apiHost: "https://api.example.com",
            clientKey: "sdk-key",
            attributes: [:],
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setStreamingHost(streamingHost: "https://streaming.example.com")
        .setStreamingHostRequestHeaders(streamingHostRequestHeaders: ["Authorization": "Bearer token"])

        XCTAssertEqual(builder.growthBookBuilderModel.streamingHost, "https://streaming.example.com")
        XCTAssertEqual(builder.growthBookBuilderModel.streamingHostRequestHeaders?["Authorization"], "Bearer token")
    }
}

/// Minimal delegate: these tests are about configuration reaching the connection, not about payloads.
private final class NoopFeaturesFlowDelegate: FeaturesFlowDelegate {
    func featuresFetchedSuccessfully(features: Features, isRemote: Bool) {}
    func featuresAPIModelSuccessfully(model: FeaturesDataModel) {}
    func featuresFetchFailed(error: SDKError, isRemote: Bool) {}
    func contextualBanditsFetchFailed(error: SDKError, isRemote: Bool) {}
    func contextualBanditsFetchedSuccessfully(contextualBandits: JSON, isRemote: Bool) {}
    func contextualBanditsCleared(isRemote: Bool) {}
    func savedGroupsFetchFailed(error: SDKError, isRemote: Bool) {}
    func savedGroupsFetchedSuccessfully(savedGroups: JSON, isRemote: Bool) {}
    func featuresUpdateIsComplete(error: SDKError?, isRemote: Bool) {}
}
