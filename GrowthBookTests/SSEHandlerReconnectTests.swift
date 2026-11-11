import XCTest
@testable import GrowthBook

final class SSEHandlerReconnectTests: XCTestCase {

    private var handler: SSEHandler!

    override func setUp() {
        super.setUp()
        handler = SSEHandler(url: URL(string: "https://example.com/events")!)
    }

    // MARK: - Initial state

    func testInitialRetryCountIsZero() {
        XCTAssertEqual(handler.retryCount, 0)
    }

    func testDefaultRetryTimeIs1000ms() {
        XCTAssertEqual(handler.retryTime, SSEHandler.DefaultRetryTime)
        XCTAssertEqual(handler.retryTime, 1000)
    }

    func testMaxRetryDelayIs5Minutes() {
        XCTAssertEqual(handler.maxRetryDelayMs, 300_000)
    }

    // MARK: - Backoff delay calculation

    func testBackoffDelayAtRetry0Is1s() {
        XCTAssertEqual(handler.backoffDelay(for: 0), 1_000)
    }

    func testBackoffDelayDoublesEachRetry() {
        let expected = [1_000, 2_000, 4_000, 8_000, 16_000]
        for (i, ms) in expected.enumerated() {
            XCTAssertEqual(handler.backoffDelay(for: i), ms, "retry \(i) should be \(ms)ms")
        }
    }

    func testBackoffDelayCappedAt5Minutes() {
        XCTAssertEqual(handler.backoffDelay(for: 9), 300_000)  // 1000 * 2^9 = 512000 → capped
        XCTAssertEqual(handler.backoffDelay(for: 10), 300_000)
    }

    /// With no attempt limit the count keeps climbing, and the old `pow(2, count)` turned into an
    /// Int trapped once it passed Int.max — a few seconds of outage on 32-bit watchOS.
    func testBackoffDelayDoesNotOverflowAtAbsurdRetryCounts() {
        XCTAssertEqual(handler.backoffDelay(for: 1_000), 300_000)
        XCTAssertEqual(handler.backoffDelay(for: Int.max), 300_000)
    }

    /// A server may send `retry: 0`. The delay must still climb rather than stay at zero.
    func testBackoffDelayHandlesAZeroRetryTime() {
        handler.retryTime = 0
        XCTAssertEqual(handler.backoffDelay(for: 0), 1)
        XCTAssertEqual(handler.backoffDelay(for: Int.max), 300_000)
    }

    func testBackoffDelayRespectsCustomRetryTime() {
        handler.retryTime = 2_000
        XCTAssertEqual(handler.backoffDelay(for: 0), 2_000)
        XCTAssertEqual(handler.backoffDelay(for: 1), 4_000)
        XCTAssertEqual(handler.backoffDelay(for: 8), 300_000)  // 2000 * 2^8 = 512000 → capped
    }

    // MARK: - Jitter

    /// The delay handed to the scheduler lands in the upper half of the computed backoff, so
    /// clients that dropped together do not come back together.
    func testJitteredDelayStaysWithinTheUpperHalfOfTheBackoff() {
        for count in 0...12 {
            let base = handler.backoffDelay(for: count)
            for _ in 0..<50 {
                let jittered = handler.jitteredDelay(for: count)
                XCTAssertGreaterThanOrEqual(jittered, base / 2, "retry \(count)")
                XCTAssertLessThanOrEqual(jittered, base, "retry \(count)")
            }
        }
    }

    /// Jitter has to survive the ceiling: that is where every client is most synchronised, and
    /// where the reference SDK loses it by multiplying before capping.
    func testJitterStillAppliesOnceTheDelayHasCapped() {
        var seen = Set<Int>()
        for _ in 0..<200 { seen.insert(handler.jitteredDelay(for: 20)) }
        XCTAssertGreaterThan(seen.count, 1, "Capped delays must not all be identical")
        XCTAssertLessThanOrEqual(seen.max() ?? 0, handler.maxRetryDelayMs)
        XCTAssertGreaterThanOrEqual(seen.min() ?? 0, handler.maxRetryDelayMs / 2)
    }

    /// A 1ms delay has no room to spread, and halving it would round to zero — which would retry
    /// immediately, the tight loop this whole area exists to prevent.
    func testJitterLeavesTheSmallestDelayAlone() {
        handler.retryTime = 0
        XCTAssertEqual(handler.jitteredDelay(for: 0), 1)
    }

    // MARK: - disconnect() resets state

    func testDisconnectSetsStatusToDisconnected() {
        handler.disconnect()
        XCTAssertEqual(handler.connectionStatus, .disconnected)
    }

    func testDisconnectResetsRetryCountOnOperationQueue() {
        // retryCount reset is dispatched to operationQueue to avoid data race;
        // flush the queue before asserting.
        handler.disconnect()
        handler.operationQueue.waitUntilAllOperationsAreFinished()
        XCTAssertEqual(handler.retryCount, 0)
    }

    // MARK: - shouldReconnect

    func testReconnectsOnStatus200() {
        XCTAssertTrue(handler.shouldReconnect(statusCode: 200))
    }

    func testDoesNotReconnectOnOther2xx() {
        XCTAssertFalse(handler.shouldReconnect(statusCode: 201))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 204))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 299))
    }

    /// A rejection that will not change on its own is believed the first time: retrying a revoked
    /// key or a wrong path forever only burns battery.
    func testDoesNotReconnectOnClientErrors() {
        XCTAssertFalse(handler.shouldReconnect(statusCode: 400))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 401))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 403))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 404))
    }

    /// The server saying "not now" — a proxy restarting mid-deploy, a gateway blip, a rate limit.
    /// Ending streaming on these froze features over something that cleared in seconds.
    func testReconnectsOnServerErrorsAndRateLimiting() {
        XCTAssertTrue(handler.shouldReconnect(statusCode: 429))
        for code in [500, 502, 503, 504, 599] {
            XCTAssertTrue(handler.shouldReconnect(statusCode: code), "HTTP \(code) must be retryable")
        }
    }

    // MARK: - Transport failures (no HTTP response)

    private func transportError() -> NSError {
        NSError(domain: NSURLErrorDomain, code: NSURLErrorTimedOut, userInfo: nil)
    }

    private func cancelledError() -> NSError {
        NSError(domain: NSURLErrorDomain, code: NSURLErrorCancelled, userInfo: nil)
    }

    /// DNS failures, connection loss and timeouts complete without an `HTTPURLResponse`. They are
    /// what the backoff exists for, so they must count as retryable.
    func testTransportFailureWithoutStatusIsRetryable() {
        XCTAssertTrue(handler.shouldReconnect(statusCode: nil))
    }

    func testTransportErrorSchedulesRetry() {
        handler.connectionStatus = .connecting
        let reported = expectation(description: "disconnect reported")
        var reconnectFlag: Bool?
        var forwardedError: NSError?
        handler.onDissconnect { _, reconnect, error in
            reconnectFlag = reconnect
            forwardedError = error
            reported.fulfill()
        }

        handler.handleStreamCompletion(statusCode: nil, error: transportError())

        XCTAssertEqual(handler.retryCount, 1, "A transport failure must consume one retry, not stop streaming")
        wait(for: [reported], timeout: 30.0)
        XCTAssertEqual(reconnectFlag, true, "Callers must be told the stream will come back")
        XCTAssertEqual(forwardedError?.code, NSURLErrorTimedOut, "The underlying error must still be surfaced")

        handler.disconnect()  // keep the scheduled reconnect from reaching the network
    }

    /// Streaming is not abandoned after any number of failures. A budget that ran out ended
    /// streaming for the life of the instance, so a phone offline for a few minutes came back to
    /// frozen features until it was relaunched.
    func testTransportErrorsKeepRetryingIndefinitely() {
        handler.connectionStatus = .connecting

        // The callback is installed up front: every completion queues its report on the main queue,
        // and those reports only run once this test starts waiting.
        let attempts = 40
        let reported = expectation(description: "every disconnect reported")
        reported.expectedFulfillmentCount = attempts
        var flags: [Bool?] = []
        handler.onDissconnect { _, reconnect, _ in
            flags.append(reconnect)
            reported.fulfill()
        }

        for _ in 0..<attempts {
            handler.handleStreamCompletion(statusCode: nil, error: transportError())
        }
        XCTAssertEqual(handler.retryCount, attempts, "Every failure must schedule another attempt")

        wait(for: [reported], timeout: 30.0)
        XCTAssertEqual(flags.count, attempts)
        XCTAssertEqual(flags.compactMap { $0 }.filter { $0 }.count, attempts,
                       "Every attempt must promise a reconnect, however many have failed")
        XCTAssertEqual(handler.backoffDelay, handler.maxRetryDelayMs,
                       "Retries settle at the ceiling rather than stopping")

        handler.disconnect()
    }

    /// The one thing that does stop it: asking. `disconnect()` while a retry is pending must stay
    /// terminal, or an explicit teardown would be undone by the reconnect it raced.
    func testDisconnectDuringBackoffIsTerminal() {
        handler.connectionStatus = .connecting
        let reported = expectation(description: "disconnect reported")
        reported.expectedFulfillmentCount = 2
        var flags: [Bool?] = []
        handler.onDissconnect { _, reconnect, _ in
            flags.append(reconnect)
            reported.fulfill()
        }

        handler.handleStreamCompletion(statusCode: nil, error: transportError())
        handler.disconnect()
        handler.handleStreamCompletion(statusCode: nil, error: transportError())

        wait(for: [reported], timeout: 30.0)
        XCTAssertEqual(flags.last ?? nil, false, "After disconnect() nothing may schedule a retry")
    }

    /// An explicitly requested disconnect must not be undone by the backoff.
    func testExplicitDisconnectIsNotRetried() {
        handler.connectionStatus = .connecting
        handler.disconnect()

        handler.handleStreamCompletion(statusCode: nil, error: cancelledError())

        XCTAssertEqual(handler.retryCount, 0, "disconnect() must not schedule a reconnect")
        XCTAssertEqual(handler.connectionStatus, .disconnected)
    }

    /// Cancellation from any other source is deliberate too, so it is not a transport failure.
    func testCancelledTaskIsNotRetried() {
        handler.connectionStatus = .connected

        handler.handleStreamCompletion(statusCode: nil, error: cancelledError())

        XCTAssertEqual(handler.retryCount, 0)
    }
}
