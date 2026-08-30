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
}
