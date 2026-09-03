import os

public enum LogLevel: Equatable, Sendable {
    case debug
    case notice
    case error
}

public enum LogCategory: String, Equatable, Sendable {
    case dock
    case layouts
    case hotkeys
    case autoQuit = "auto-quit"
    case launchAtLogin = "launch-at-login"
}

public protocol EventLog: Sendable {
    func record(_ level: LogLevel, _ category: LogCategory, _ message: String)
}

public struct SystemEventLog: EventLog {
    static let subsystem = "io.github.lilmikazuki.Shitsurae"

    public init() {}

    public func record(_ level: LogLevel, _ category: LogCategory, _ message: String) {
        let logger = Logger(subsystem: Self.subsystem, category: category.rawValue)
        switch level {
        case .debug: logger.debug("\(message, privacy: .public)")
        case .notice: logger.notice("\(message, privacy: .public)")
        case .error: logger.error("\(message, privacy: .public)")
        }
    }
}
