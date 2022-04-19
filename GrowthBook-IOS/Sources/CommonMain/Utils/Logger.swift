import Logging

// GrowthBook default logger
var logger = Logger(label: "GrowthBook-Logger")

@objc public enum LoggerLevel: NSInteger {
    case trace = 0
    case debug = 1
    case info = 2
    case notice = 3
    case warning = 4
    case error = 5
    case critical = 6
}

extension Logger {
    static func getLoggingLevel(from level: LoggerLevel) -> Logger.Level {
        switch level {
        case .trace:
            return .trace
        case .info:
            return .info
        case .debug:
            return .debug
        case .notice:
            return .notice
        case .warning:
            return .warning
        case .error:
            return .error
        case .critical:
            return .critical
        }
    }
}

