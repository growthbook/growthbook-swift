import XCTest
import Combine

@testable import GrowthBook

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
class FeaturesPublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    /// Offline SDK preloaded with a single "alpha" feature.
    private func makeSDK(clientKey: String = "features-publisher-test") -> GrowthBookSDK {
        let payload = """
        {"features": {"alpha": {"defaultValue": 1}}}
        """.data(using: .utf8)!

        return GrowthBookBuilder(
            apiHost: "https://example.com",
            clientKey: clientKey,
            attributes: [:],
            features: payload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()
    }

    func testCurrentValueReplayedToNewSubscriber() {
        let sdk = makeSDK()
        var received: [[String: Feature]] = []
        sdk.featuresPublisher.sink { received.append($0) }.store(in: &cancellables)

        // CurrentValueSubject replays the latest features to a new subscriber immediately.
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(Set(received.first?.keys ?? [:].keys), ["alpha"])
    }

    func testEmitsOnUpdate() {
        let sdk = makeSDK()
        var received: [[String: Feature]] = []
        sdk.featuresPublisher.sink { received.append($0) }.store(in: &cancellables)

        sdk.featuresFetchedSuccessfully(features: ["beta": Feature(defaultValue: JSON(2))], isRemote: true)

        XCTAssertEqual(received.count, 2)
        XCTAssertEqual(Set(received.last?.keys ?? [:].keys), ["beta"])
    }

    func testMultipleSubscribersAllReceiveUpdate() {
        let sdk = makeSDK()
        var a: [[String: Feature]] = []
        var b: [[String: Feature]] = []
        sdk.featuresPublisher.sink { a.append($0) }.store(in: &cancellables)
        sdk.featuresPublisher.sink { b.append($0) }.store(in: &cancellables)

        sdk.featuresFetchedSuccessfully(features: ["gamma": Feature(defaultValue: JSON(3))], isRemote: true)

        XCTAssertEqual(Set(a.last?.keys ?? [:].keys), ["gamma"])
        XCTAssertEqual(Set(b.last?.keys ?? [:].keys), ["gamma"])
    }

    func testNoEmitWhenStableSessionLatched() {
        // With stableSession enabled, a second update must NOT be applied or emitted.
        let payload = """
        {"features": {"alpha": {"defaultValue": 1}}}
        """.data(using: .utf8)!
        let sdk = GrowthBookBuilder(
            apiHost: "https://example.com",
            clientKey: "features-publisher-stable",
            attributes: [:],
            features: payload,
            trackingCallback: { _, _ in },
            backgroundSync: false
        )
        .setStableSession(true)
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: nil, error: nil))
        .initializer()

        var received: [[String: Feature]] = []
        sdk.featuresPublisher.sink { received.append($0) }.store(in: &cancellables)

        sdk.featuresFetchedSuccessfully(features: ["beta": Feature(defaultValue: JSON(2))], isRemote: true)

        // Only the initial replay; the locked-session update is ignored.
        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(Set(received.first?.keys ?? [:].keys), ["alpha"])
    }
}
