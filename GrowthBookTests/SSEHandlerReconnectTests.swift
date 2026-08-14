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

    func testMaxRetryCountIs10() {
        XCTAssertEqual(handler.maxRetryCount, 10)
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

    func testBackoffDelayCappedAt30s() {
        XCTAssertEqual(handler.backoffDelay(for: 5), 30_000)  // 1000 * 2^5 = 32000 → capped
        XCTAssertEqual(handler.backoffDelay(for: 10), 30_000)
    }

    func testBackoffDelayRespectsCustomRetryTime() {
        handler.retryTime = 2_000
        XCTAssertEqual(handler.backoffDelay(for: 0), 2_000)
        XCTAssertEqual(handler.backoffDelay(for: 1), 4_000)
        XCTAssertEqual(handler.backoffDelay(for: 4), 30_000)  // 2000 * 2^4 = 32000 → capped
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

    func testDoesNotReconnectOnClientOrServerErrors() {
        XCTAssertFalse(handler.shouldReconnect(statusCode: 400))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 404))
        XCTAssertFalse(handler.shouldReconnect(statusCode: 500))
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

    func testTransportErrorSchedulesBoundedRetry() {
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

    /// The retry budget is shared with HTTP failures, so a permanently broken connection stops.
    func testTransportErrorsStopAfterMaxRetries() {
        handler.connectionStatus = .connecting

        // The callback is installed up front: every completion queues its report on the main queue,
        // and those reports only run once this test starts waiting.
        let attempts = handler.maxRetryCount + 1
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
        XCTAssertEqual(handler.retryCount, handler.maxRetryCount, "The retry limit must not be exceeded")

        wait(for: [reported], timeout: 30.0)
        XCTAssertEqual(flags.count, attempts)
        XCTAssertEqual(flags.dropLast().compactMap { $0 }.filter { $0 }.count, handler.maxRetryCount,
                       "Every attempt within the budget must promise a reconnect")
        XCTAssertEqual(flags.last ?? nil, false, "Past the retry limit the stream must stay down")

        handler.disconnect()
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
