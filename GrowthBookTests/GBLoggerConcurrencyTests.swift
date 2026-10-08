import XCTest

@testable import GrowthBook

/// `GBLogger` claims `@unchecked Sendable`, which the compiler cannot verify — these tests cover the
/// part it has to earn: configuration is mutable from any thread while logging happens on another.
final class GBLoggerConcurrencyTests: XCTestCase {

    func testConfigurationRoundTrips() {
        let logger = GBLogger()

        logger.minLevel = .warning
        logger.enabled = false
        logger.theme = nil

        XCTAssertEqual(logger.minLevel, .warning)
        XCTAssertFalse(logger.enabled)
        XCTAssertNil(logger.theme)
    }

    /// The formatter setter used to be a stored property with a `didSet` that pointed the formatter
    /// back at its logger. Now that it is lock-guarded, that wiring has to happen in the setter —
    /// without it, themed output silently loses its colours.
    func testAssigningFormatterKeepsItPointingAtTheLogger() {
        let logger = GBLogger()
        // A distinct instance, not the shared `Formatter.default`: that one is already wired to
        // whichever logger was created last, so asserting on it would prove nothing.
        let formatter = Formatter("%@ %@", [.level, .message])

        logger.formatter = formatter

        XCTAssertTrue(logger.formatter === formatter)
        XCTAssertTrue(formatter.logger === logger, "The formatter must be wired back to its logger")
    }

    /// Reconfiguring while logging from other threads must neither crash nor deadlock. The lock is
    /// deliberately not held across formatting, which is where a naive implementation deadlocks:
    /// `Formatter` reads `logger?.theme` while it formats.
    func testConcurrentReconfigurationWhileLogging() {
        let logger = GBLogger(minLevel: .trace)
        let group = DispatchGroup()

        for i in 0..<50 {
            DispatchQueue.global().async(group: group) {
                logger.info("message \(i)")
            }
            DispatchQueue.global().async(group: group) {
                logger.minLevel = (i % 2 == 0) ? .trace : .error
                logger.enabled = (i % 3 != 0)
                _ = logger.format
                _ = logger.colors
            }
        }

        let finished = group.wait(timeout: .now() + 30)
        XCTAssertEqual(finished, .success, "Logging and reconfiguration must not deadlock")
        XCTAssertTrue([Level.trace, .error].contains(logger.minLevel))
    }
}
