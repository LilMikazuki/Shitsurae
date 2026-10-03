import AppKit
import Foundation

public protocol DockRestarting: Sendable {
    func restart() throws(DockRestartError)
    func waitUntilRunning()
}

public enum DockRestartError: Error, Equatable {
    case terminateRefused
    case overwritten
}

extension DockRestartError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .terminateRefused:
            "The Dock was asked to quit but is still running."
        case .overwritten:
            "The Dock restarted, but each time it saved its own tiles over what was written."
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
        // `terminate()` answers false for a Dock that has already gone and true for one that
        // ignores the request; only liveness afterwards means anything. It also answers false
        // for a Dock still starting, which then never quits: that one has to be asked again.
        var unreached = asked.filter { !$0.terminate() }

        let deadline = DispatchTime.now() + timeout
        while asked.contains(where: \.isRunning) {
            guard DispatchTime.now() < deadline else {
                throw DockRestartError.terminateRefused
            }
            Thread.sleep(forTimeInterval: pollInterval)
            unreached.removeAll { !$0.isRunning || $0.terminate() }
        }
    }

    public func waitUntilRunning() {
        let deadline = DispatchTime.now() + timeout
        while !processes().contains(where: \.isRunning), DispatchTime.now() < deadline {
            Thread.sleep(forTimeInterval: pollInterval)
        }
    }
}
