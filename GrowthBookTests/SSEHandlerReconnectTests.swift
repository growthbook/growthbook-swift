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
}
