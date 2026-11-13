//
//  LoggingManager.swift
//  GrowthBookTests
//
//  Created by Volodymyr Nazarkevych on 26.04.2022.
//

import Foundation
import os

public enum Level: Int, Sendable {
    case trace, debug, info, warning, error

    var description: String {
        return String(describing: self).uppercased()
    }
}

extension Level: Comparable {
    public static func < (lhs: Level, rhs: Level) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
}

/// The SDK logger.
///
/// `@unchecked Sendable` is a claim the compiler cannot verify, so it has to be earned: every
/// mutable property below is guarded by `stateLock`, and the only other stored state — the logging
/// queue and the OS logger — is immutable after init. Configuration can therefore be changed from
/// any thread while logging happens on another.
///
/// The lock is never held across formatting: `Formatter` reads `logger?.theme` while it formats, so
/// holding it there would deadlock on the very first themed message.
open class GBLogger: @unchecked Sendable {
    private let stateLock = NSLock()

    private var _enabled: Bool = true
    private var _formatter: Formatter
    private var _theme: Theme?
    private var _minLevel: Level

    /// The logger state.
    open var enabled: Bool {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _enabled }
        set { stateLock.lock(); defer { stateLock.unlock() }; _enabled = newValue }
    }

    /// The logger formatter.
    open var formatter: Formatter {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _formatter }
        set {
            stateLock.lock()
            defer { stateLock.unlock() }
            _formatter = newValue
            newValue.logger = self
        }
    }

    /// The logger theme.
    open var theme: Theme? {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _theme }
        set { stateLock.lock(); defer { stateLock.unlock() }; _theme = newValue }
    }

    /// The minimum level of severity.
    open var minLevel: Level {
        get { stateLock.lock(); defer { stateLock.unlock() }; return _minLevel }
        set { stateLock.lock(); defer { stateLock.unlock() }; _minLevel = newValue }
    }

    /// The logger format.
    open var format: String {
        return formatter.description
    }

    /// The logger colors
    open var colors: String {
        return theme?.description ?? ""
    }

    /// The queue used for logging.
    private let queue = DispatchQueue(label: "delba.log")

    private let osLogger: Any? = {
        if #available(iOS 14.0, macCatalyst 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *) {
            return Logger(subsystem: "com.growthbook.sdk", category: "GrowthBook")
        } else {
            return OSLog(subsystem: "com.growthbook.sdk", category: "GrowthBook")
        }
    }()
    /**
     Creates and returns a new logger.

     - parameter formatter: The formatter.
     - parameter theme:     The theme.
     - parameter minLevel:  The minimum level of severity.

     - returns: A newly created logger.
     */
    public init(formatter: Formatter = .default, theme: Theme? = nil, minLevel: Level = .trace) {
        // Assign the storage directly: the instance has not escaped yet, so there is nothing to
        // serialise against, and going through the setters would take a lock for no reason.
        self._formatter = formatter
        self._theme = theme
        self._minLevel = minLevel

        formatter.logger = self
    }

    /**
     Logs a message with a trace severity level.

     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func trace(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.trace, items, separator, terminator, file, line, column, function)
    }

    /**
     Logs a message with a debug severity level.

     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func debug(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.debug, items, separator, terminator, file, line, column, function)
    }

    /**
     Logs a message with an info severity level.

     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func info(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.info, items, separator, terminator, file, line, column, function)
    }

    /**
     Logs a message with a warning severity level.

     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func warning(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.warning, items, separator, terminator, file, line, column, function)
    }

    /**
     Logs a message with an error severity level.

     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    open func error(_ items: Any..., separator: String = " ", terminator: String = "\n", file: String = #file, line: Int = #line, column: Int = #column, function: String = #function) {
        log(.error, items, separator, terminator, file, line, column, function)
    }

    /**
     Logs a message.

     - parameter level:      The severity level.
     - parameter items:      The items to log.
     - parameter separator:  The separator between the items.
     - parameter terminator: The terminator of the log message.
     - parameter file:       The file in which the log happens.
     - parameter line:       The line at which the log happens.
     - parameter column:     The column at which the log happens.
     - parameter function:   The function in which the log happens.
     */
    private func log(_ level: Level, _ items: [Any], _ separator: String, _ terminator: String,
                     _ file: String, _ line: Int, _ column: Int, _ function: String) {
        guard enabled && level >= minLevel else { return }
        
        let date = Date()
        
        let result = formatter.format(
            level: level,
            items: items,
            separator: separator,
            terminator: terminator,
            file: file,
            line: line,
            column: column,
            function: function,
            date: date
        )
        
        queue.async {
            if #available(iOS 14.0, macCatalyst 14.0, macOS 11.0, tvOS 14.0, watchOS 7.0, visionOS 1.0, *) {
                guard let logger = self.osLogger as? Logger else { return }
                switch level {
                case .trace, .debug:
                    logger.debug("\(result)")
                case .info:
                    logger.info("\(result)")
                case .warning:
                    logger.warning("\(result)")
                case .error:
                    logger.error("\(result)")
                }
            } else {
                if let logger = self.osLogger as? OSLog {
                    os_log("%@", logger, result)
                } else {
                    Swift.print(result, separator: "", terminator: "")
                }
            }
        }
    }
}
