import AppKit
import Foundation

public protocol DockRestarting: Sendable {
    func restart() throws
}

public enum DockRestartError: Error, Equatable {
    case terminateRefused
}

extension DockRestartError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .terminateRefused:
            "The Dock process refused to terminate."
        }
    }
}

public protocol DockProcess: Sendable {
    func terminate() -> Bool
}

extension NSRunningApplication: DockProcess {}

public final class DockRestarter: DockRestarting {
    public static let bundleIdentifier = "com.apple.dock"
    private let processes: @Sendable () -> [any DockProcess]

    public init(processes: @escaping @Sendable () -> [any DockProcess] = {
        NSRunningApplication
            .runningApplications(withBundleIdentifier: DockRestarter.bundleIdentifier)
    }) {
        self.processes = processes
    }

    public func restart() throws {
        // No Dock running means nothing to restart: launchd starts one, and it
        // reads the domain that was just written.
        for app in processes() {
            guard app.terminate() else {
                throw DockRestartError.terminateRefused
            }
        }
    }
}
