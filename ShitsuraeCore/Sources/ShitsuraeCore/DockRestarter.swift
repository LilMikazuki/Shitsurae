import AppKit
import Foundation

public protocol DockRestarting: Sendable {
    func restart() throws(DockRestartError)
}

public enum DockRestartError: Error, Equatable {
    case terminateRefused
}

extension DockRestartError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .terminateRefused:
            "The Dock was asked to quit but is still running."
        }
    }
}

public protocol DockProcess: Sendable {
    func terminate() -> Bool
    var isRunning: Bool { get }
}

extension NSRunningApplication: DockProcess {
    /// `isTerminated` is refreshed by the main run loop, which the CLI never runs.
    /// The kernel answers anywhere.
    public var isRunning: Bool {
        processIdentifier > 0 && kill(processIdentifier, 0) == 0
    }
}

public final class DockRestarter: DockRestarting {
    public static let bundleIdentifier = "com.apple.dock"
    private let processes: @Sendable () -> [any DockProcess]

    private let timeout: TimeInterval
    private let pollInterval: TimeInterval

    public init(
        processes: @escaping @Sendable () -> [any DockProcess] = {
            NSRunningApplication
                .runningApplications(withBundleIdentifier: DockRestarter.bundleIdentifier)
        },
        timeout: TimeInterval = 5,
        pollInterval: TimeInterval = 0.02
    ) {
        self.processes = processes
        self.timeout = timeout
        self.pollInterval = pollInterval
    }

    public func restart() throws(DockRestartError) {
        // No Dock running means nothing to restart: the next Dock to start reads
        // the domain that was just written.
        let asked = processes()
        for app in asked {
            // `terminate()` answers false for a Dock that has already gone and true
            // for one that ignores the request; only liveness afterwards means anything.
            _ = app.terminate()
        }

        let deadline = DispatchTime.now() + timeout
        while asked.contains(where: \.isRunning) {
            guard DispatchTime.now() < deadline else {
                throw DockRestartError.terminateRefused
            }
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }
}
