import AppKit
import Foundation

public protocol AppQuitting: Sendable {
    func runningBundleIds() -> Set<String>
    func quit(bundleIds: Set<String>)
}

public struct WorkspaceAppQuitter: AppQuitting {
    public init() {}

    public func runningBundleIds() -> Set<String> {
        Set(quittable().compactMap(\.bundleIdentifier))
    }

    public func quit(bundleIds: Set<String>) {
        for app in quittable() {
            guard let id = app.bundleIdentifier, bundleIds.contains(id) else { continue }
            app.terminate()
        }
    }

    /// Finder has no quit item of its own, and the agents behind the menu bar
    /// were never in the Dock to begin with.
    private func quittable() -> [NSRunningApplication] {
        let mine = Bundle.main.bundleIdentifier
        return NSWorkspace.shared.runningApplications.filter {
            Self.isQuittable(bundleId: $0.bundleIdentifier, policy: $0.activationPolicy, mine: mine)
        }
    }

    static func isQuittable(
        bundleId: String?,
        policy: NSApplication.ActivationPolicy,
        mine: String?
    ) -> Bool {
        guard let bundleId, policy == .regular else { return false }
        return bundleId != mine && bundleId != finder
    }

    private static let finder = "com.apple.finder"
}
