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

    // MARK: - Emission ordering

    /// The SDK lock is released before sending, so two concurrent updates can be applied in one
    /// order and reach the subject in the other. The later-applied update must win: otherwise
    /// CurrentValueSubject keeps replaying features the SDK no longer holds.
    func testSupersededEmissionIsNotDelivered() {
        let sdk = makeSDK(clientKey: "features-publisher-ordering")
        var received: [[String: Feature]] = []
        sdk.featuresPublisher.sink { received.append($0) }.store(in: &cancellables)
        XCTAssertEqual(received.count, 1, "Precondition: the replayed initial value")

        let newer: [String: Feature] = ["newer": Feature(defaultValue: JSON(2))]
        let older: [String: Feature] = ["older": Feature(defaultValue: JSON(1))]

        // Applied as 6 then 7, but arriving here in the opposite order.
        sdk.emitFeaturesChange(newer, generation: 7)
        sdk.emitFeaturesChange(older, generation: 6)

        XCTAssertEqual(received.count, 2, "The superseded update must not be delivered")
        XCTAssertEqual(Set(received.last?.keys ?? [:].keys), ["newer"],
                       "Subscribers must be left holding the update that was applied last")
    }

    /// Control: emissions that arrive in applied order are all delivered.
    func testEmissionsInAppliedOrderAreAllDelivered() {
        let sdk = makeSDK(clientKey: "features-publisher-ordering-control")
        var received: [[String: Feature]] = []
        sdk.featuresPublisher.sink { received.append($0) }.store(in: &cancellables)

        sdk.emitFeaturesChange(["first": Feature(defaultValue: JSON(1))], generation: 1)
        sdk.emitFeaturesChange(["second": Feature(defaultValue: JSON(2))], generation: 2)

        XCTAssertEqual(received.count, 3)
        XCTAssertEqual(Set(received.last?.keys ?? [:].keys), ["second"])
    }

    /// End-to-end invariant under concurrency: once every update has been applied, what the
    /// subject holds must match what the SDK holds.
    func testConcurrentUpdatesLeaveSubjectMatchingSDK() {
        let sdk = makeSDK(clientKey: "features-publisher-concurrency")
        var received: [[String: Feature]] = []
        let guardLock = NSLock()
        sdk.featuresPublisher.sink { value in
            guardLock.lock(); received.append(value); guardLock.unlock()
        }.store(in: &cancellables)

        let group = DispatchGroup()
        for i in 0..<20 {
            DispatchQueue.global().async(group: group) {
                sdk.featuresFetchedSuccessfully(features: ["flag-\(i)": Feature(defaultValue: JSON(i))], isRemote: true)
            }
        }
        group.wait()

        let sdkFeatures = Set(sdk.getFeatures().keys)
        guardLock.lock(); let last = Set(received.last?.keys ?? [:].keys); guardLock.unlock()
        XCTAssertEqual(last, sdkFeatures,
                       "The value replayed to new subscribers must be the features the SDK actually holds")
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
