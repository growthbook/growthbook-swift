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
        handler.retryCount = 0
        XCTAssertEqual(handler.backoffDelay, 1_000)
    }

    func testBackoffDelayDoublesEachRetry() {
        let expected = [1_000, 2_000, 4_000, 8_000, 16_000]
        for (i, ms) in expected.enumerated() {
            handler.retryCount = i
            XCTAssertEqual(handler.backoffDelay, ms, "retry \(i) should be \(ms)ms")
        }
    }

    func testBackoffDelayCappedAt30s() {
        handler.retryCount = 5   // 1000 * 2^5 = 32000 → capped at 30000
        XCTAssertEqual(handler.backoffDelay, 30_000)

        handler.retryCount = 10
        XCTAssertEqual(handler.backoffDelay, 30_000)
    }

    func testBackoffDelayRespectCustomRetryTime() {
        handler.retryTime = 2_000
        handler.retryCount = 0
        XCTAssertEqual(handler.backoffDelay, 2_000)

        handler.retryCount = 1
        XCTAssertEqual(handler.backoffDelay, 4_000)

        handler.retryCount = 4   // 2000 * 2^4 = 32000 → capped at 30000
        XCTAssertEqual(handler.backoffDelay, 30_000)
    }

    // MARK: - disconnect() resets state

    func testDisconnectResetsRetryCount() {
        handler.retryCount = 7
        handler.disconnect()
        XCTAssertEqual(handler.retryCount, 0)
    }

    func testDisconnectSetsStatusToDisconnected() {
        handler.disconnect()
        XCTAssertEqual(handler.connectionStatus, .disconnected)
    }
}
