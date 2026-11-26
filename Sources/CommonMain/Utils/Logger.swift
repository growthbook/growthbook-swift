 
import Foundation

// GrowthBook default logger.
//
// A `let`: nothing reassigns this reference, and a mutable global is rejected outright under the
// Swift 6 language mode as unsafe shared state. Configuration still changes at runtime — through
// GBLogger's own lock-guarded properties — so `logger.minLevel = ...` keeps working.
let logger = GBLogger()

@objc public enum LoggerLevel: NSInteger {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
}

extension GBLogger {
    static func getLoggingLevel(from level: LoggerLevel) -> Level {
        switch level {
        case .trace:
            return .trace
        case .info:
            return .info
        case .debug:
            return .debug
        case .warning:
            return .warning
        case .error:
            return .error
        }
    }
}

