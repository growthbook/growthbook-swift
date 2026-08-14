import XCTest
import Combine

@testable import GrowthBook

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
class ExperimentsPublisherTests: XCTestCase {

    private var cancellables = Set<AnyCancellable>()

    override func tearDown() {
        cancellables.removeAll()
        super.tearDown()
    }

    /// Offline SDK preloaded with a single feature so no network is needed.
    private func makeSDK(clientKey: String = "experiments-publisher-test") -> GrowthBookSDK {
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

    private func experiment(_ key: String) -> Experiment {
        Experiment(key: key, variations: [JSON("control"), JSON("variant")])
    }

    func testEmitsOnRun() {
        let sdk = makeSDK()
        var received: [ExperimentRun] = []
        sdk.experimentsPublisher.sink { received.append($0) }.store(in: &cancellables)

        let result = sdk.run(experiment: experiment("exp-1"))

        XCTAssertEqual(received.count, 1)
        XCTAssertEqual(received.first?.experiment.key, "exp-1")
        XCTAssertEqual(received.first?.result.variationId, result.variationId)
    }

    func testNoReplayForNewSubscriber() {
        let sdk = makeSDK()
        var received: [ExperimentRun] = []
        // PassthroughSubject: subscribing without a prior run yields nothing.
        sdk.experimentsPublisher.sink { received.append($0) }.store(in: &cancellables)

        XCTAssertEqual(received.count, 0)
    }

    func testLateSubscriberMissesEarlierRuns() {
        let sdk = makeSDK()

        // Run before subscribing — must not be replayed.
        _ = sdk.run(experiment: experiment("early"))

        var received: [ExperimentRun] = []
        sdk.experimentsPublisher.sink { received.append($0) }.store(in: &cancellables)

        _ = sdk.run(experiment: experiment("late"))

        XCTAssertEqual(received.map { $0.experiment.key }, ["late"])
    }

    func testMultipleSubscribersAllReceiveRun() {
        let sdk = makeSDK()
        var a: [ExperimentRun] = []
        var b: [ExperimentRun] = []
        sdk.experimentsPublisher.sink { a.append($0) }.store(in: &cancellables)
        sdk.experimentsPublisher.sink { b.append($0) }.store(in: &cancellables)

        _ = sdk.run(experiment: experiment("shared"))

        XCTAssertEqual(a.map { $0.experiment.key }, ["shared"])
        XCTAssertEqual(b.map { $0.experiment.key }, ["shared"])
    }

    func testExistingSubscribeCallbackStillFires() {
        let sdk = makeSDK()
        var callbackKeys: [String] = []
        sdk.subscribe { exp, _ in callbackKeys.append(exp.key) }

        var publisherKeys: [String] = []
        sdk.experimentsPublisher.sink { publisherKeys.append($0.experiment.key) }.store(in: &cancellables)

        _ = sdk.run(experiment: experiment("both"))

        // The legacy callback and the new publisher must both fire.
        XCTAssertEqual(callbackKeys, ["both"])
        XCTAssertEqual(publisherKeys, ["both"])
    }
}
