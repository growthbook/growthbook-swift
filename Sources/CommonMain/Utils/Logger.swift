 
import Foundation

// GrowthBook default logger
var logger = Logger()

@objc public enum LoggerLevel: NSInteger, Sendable {
    case trace = 0
    case debug = 1
    case info = 2
    case warning = 3
    case error = 4
}

extension LoggerLevel {
    public var loggingLevel: Level {
        switch self {
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

extension Logger {
    static func getLoggingLevel(from level: LoggerLevel) -> Level {
        level.loggingLevel
    }
}

