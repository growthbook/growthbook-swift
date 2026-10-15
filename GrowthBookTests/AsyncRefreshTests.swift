import XCTest

@testable import GrowthBook

@available(iOS 13.0, tvOS 13.0, watchOS 6.0, macOS 10.15, *)
final class AsyncRefreshTests: XCTestCase {

    private let apiHost = "https://host.com"
    private let clientKey = "async-refresh-tests"

    private func makeSDK(
        successResponse: String?,
        error: SDKError?,
        refreshHandler: CacheRefreshHandler? = nil
    ) -> GrowthBookSDK {
        GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            encryptionKey: nil,
            attributes: [:],
            trackingCallback: { _, _ in },
            refreshHandler: refreshHandler,
            backgroundSync: false,
            ttlSeconds: 0 // force a network attempt on every refresh
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: successResponse, error: error))
        .initializer()
    }

    func testRefreshSucceeds() async throws {
        let sdk = makeSDK(successResponse: MockResponse().successResponse, error: nil)

        // Should complete without throwing and apply features.
        try await sdk.refresh()

        XCTAssertFalse(sdk.getFeatures().isEmpty, "Features should be available after a successful refresh")
    }

    func testRefreshThrowsOnNetworkFailure() async throws {
        sdk_clearCache()
        let sdk = makeSDK(successResponse: nil, error: .failedToLoadData)

        do {
            try await sdk.refresh()
            XCTFail("refresh() should throw when the network fetch fails")
        } catch let error as SDKError {
            XCTAssertEqual(error.code, .failedToFetchData)
        }
    }

    func testRefreshResumesExactlyOnceForConcurrentCallers() async throws {
        let sdk = makeSDK(successResponse: MockResponse().successResponse, error: nil)

        // Multiple concurrent awaiters must all resume (no hang, no double-resume crash).
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<5 {
                group.addTask { try await sdk.refresh() }
            }
            try await group.waitForAll()
        }
    }

    func testExistingRefreshHandlerStillFiresAlongsideAsyncRefresh() async throws {
        final class Flag: @unchecked Sendable {
            private let lock = NSLock()
            private var _count = 0
            var count: Int { lock.lock(); defer { lock.unlock() }; return _count }
            func bump() { lock.lock(); _count += 1; lock.unlock() }
        }
        let flag = Flag()

        let sdk = makeSDK(
            successResponse: MockResponse().successResponse,
            error: nil,
            refreshHandler: { _ in flag.bump() }
        )
        let baseline = flag.count // may include the init-time refresh

        try await sdk.refresh()

        XCTAssertGreaterThan(flag.count, baseline, "The persistent refreshHandler must still fire for an async refresh")
    }

    // MARK: - evaluate() (remote evaluation)

    private func makeRemoteEvalSDK(successResponse: String?, error: SDKError?) -> GrowthBookSDK {
        GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            encryptionKey: nil,
            attributes: [:],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false,
            remoteEval: true,
            ttlSeconds: 0
        )
        .setNetworkDispatcher(networkDispatcher: MockNetworkClient(successResponse: successResponse, error: error))
        .initializer()
    }

    func testEvaluateThrowsWhenRemoteEvalDisabled() async {
        // makeSDK builds an SDK without remoteEval — evaluate() must fail fast, not hang.
        let sdk = makeSDK(successResponse: MockResponse().successResponse, error: nil)
        do {
            try await sdk.evaluate()
            XCTFail("evaluate() must throw when remote eval is not enabled")
        } catch let error as SDKError {
            XCTAssertEqual(error.code, .remoteEvalNotEnabled)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testEvaluateSucceedsWithRemoteEval() async throws {
        let sdk = makeRemoteEvalSDK(successResponse: MockResponse().successResponse, error: nil)
        try await sdk.evaluate()
        XCTAssertFalse(sdk.getFeatures().isEmpty, "Remote eval should apply features on success")
    }

    func testEvaluateThrowsOnNetworkFailure() async {
        sdk_clearCache()
        let sdk = makeRemoteEvalSDK(successResponse: nil, error: .failedToLoadData)
        do {
            try await sdk.evaluate()
            XCTFail("evaluate() should throw on a remote-eval network failure")
        } catch is SDKError {
            // expected
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    private func sdk_clearCache() {
        CachingManager(apiKey: clientKey).clearCache()
    }

    /// The reviewer's scenario on #179: two overlapping refreshes with opposite results, completing
    /// in reverse order. Each caller must see the outcome of the request it started — before the
    /// waiters were tied to their own fetch, whichever request finished first resumed all of them.
    func testEachAwaiterResumesWithItsOwnRefreshResult() async throws {
        sdk_clearCache()
        let network = DeferredNetworkClient()
        let sdk = GrowthBookBuilder(
            apiHost: apiHost,
            clientKey: clientKey,
            encryptionKey: nil,
            attributes: [:],
            trackingCallback: { _, _ in },
            refreshHandler: nil,
            backgroundSync: false,
            ttlSeconds: 0
        )
        .setNetworkDispatcher(networkDispatcher: network)
        .initializer()

        // init fetches on its own, and that request is one of the ones that must not resume a caller.
        try await waitForParkedRequests(network, count: 1)

        let failingOutcome = OutcomeBox()
        let failingCaller = Task {
            do { try await sdk.refresh(); failingOutcome.settle(nil) }
            catch { failingOutcome.settle(error) }
        }
        try await waitForParkedRequests(network, count: 2)

        let succeedingOutcome = OutcomeBox()
        let succeedingCaller = Task {
            do { try await sdk.refresh(); succeedingOutcome.settle(nil) }
            catch { succeedingOutcome.settle(error) }
        }
        try await waitForParkedRequests(network, count: 3)

        // Finish the second caller's request first, then init's — neither belongs to the first caller.
        let payload = MockResponse().successResponse.data(using: .utf8) ?? Data()
        network.complete(2, with: .success(payload))
        _ = await succeedingCaller.value
        network.complete(0, with: .success(payload))

        // Waiting longer can only leave this caller suspended, which is the passing outcome; the
        // failure it catches is a resume that carries someone else's result.
        try await Task.sleep(nanoseconds: 500_000_000)
        XCTAssertFalse(
            failingOutcome.isSettled,
            "a caller was resumed by a refresh it did not start"
        )
        XCTAssertNil(succeedingOutcome.storedError, "the second caller's own request succeeded")

        network.complete(1, with: .failure(SDKError.failedToLoadData))
        _ = await failingCaller.value

        XCTAssertTrue(failingOutcome.isSettled, "the first caller should resume once its own request fails")
        XCTAssertEqual((failingOutcome.storedError as? SDKError)?.code, .failedToFetchData)
    }

    private func waitForParkedRequests(_ network: DeferredNetworkClient, count: Int) async throws {
        for _ in 0..<250 {
            if network.parkedCount >= count { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("expected \(count) parked requests, saw \(network.parkedCount)")
    }
}

/// Network double that parks every request, so a test decides what each one returns and in which
/// order they finish.
private final class DeferredNetworkClient: NetworkProtocol {
    private let lock = NSLock()
    private var parked: [(success: (Data) -> Void, failure: (Error) -> Void)] = []

    var parkedCount: Int {
        lock.lock(); defer { lock.unlock() }
        return parked.count
    }

    func consumeGETRequest(url: String, successResult: @escaping (Data) -> Void, errorResult: @escaping (Error) -> Void) {
        lock.lock()
        parked.append((success: successResult, failure: errorResult))
        lock.unlock()
    }

    func consumePOSTRequest(url: String, params: [String: Any], successResult: @escaping (Data) -> Void, errorResult: @escaping (any Error) -> Void) {
        consumeGETRequest(url: url, successResult: successResult, errorResult: errorResult)
    }

    func complete(_ index: Int, with result: Result<Data, Error>) {
        lock.lock()
        let request = parked[index]
        lock.unlock()
        switch result {
        case .success(let data): request.success(data)
        case .failure(let error): request.failure(error)
        }
    }
}

/// Records how an awaiting caller resumed, so a test can assert that it has *not* resumed yet.
private final class OutcomeBox {
    private let lock = NSLock()
    private var settled = false
    private var error: Error?

    var isSettled: Bool {
        lock.lock(); defer { lock.unlock() }
        return settled
    }

    var storedError: Error? {
        lock.lock(); defer { lock.unlock() }
        return error
    }

    func settle(_ error: Error?) {
        lock.lock()
        settled = true
        self.error = error
        lock.unlock()
    }
}
