import Foundation

public enum DockApplyOutcome: Equatable, Sendable {
    case alreadyHeld
    case written(attempts: Int)
}

public struct DockEngine: Sendable {
    private static let writesBeforeGivingUp = 3

    private let store: DockPreferenceStore
    private let restarter: DockRestarting

    init(store: DockPreferenceStore, restarter: DockRestarting) {
        self.store = store
        self.restarter = restarter
    }

    public static func live() -> DockEngine {
        DockEngine(store: CFPreferencesDockStore(), restarter: DockRestarter())
    }

    public func read() throws(DockError) -> DockState {
        try read(from: store)
    }

    public func preview(_ state: DockState) throws(DockError) -> DockState {
        _ = try read()

        var seed: [String: Any] = [:]
        for key in DockKey.all {
            if let value = store.value(forKey: key) {
                seed[key] = value
            }
        }
        let sandbox = InMemoryDockStore(seed)
        try write(state, to: sandbox)
        return try read(from: sandbox)
    }

    @discardableResult
    public func apply(_ state: DockState) throws(DockError) -> DockApplyOutcome {
        try writeUntilKept(state, readingBackAs: preview(state))
    }

    @discardableResult
    public func applyIfNeeded(_ state: DockState) throws(DockError) -> DockApplyOutcome {
        let current = try read()
        let wanted = try preview(state)
        guard wanted != current else { return .alreadyHeld }
        return try writeUntilKept(state, readingBackAs: wanted)
    }

    private func writeUntilKept(
        _ state: DockState,
        readingBackAs wanted: DockState
    ) throws(DockError) -> DockApplyOutcome {
        for attempt in 1 ... Self.writesBeforeGivingUp {
            if attempt > 1 {
                // The Dock that came back read what the old one saved. Writing before it is
                // listed leaves it running with those tiles and nothing to restart.
                restarter.waitUntilRunning()
            }
            try write(state, to: store)
            try restart()
            if holds(wanted) {
                return .written(attempts: attempt)
            }
        }
        throw .restart(.overwritten)
    }

    private func holds(_ wanted: DockState) -> Bool {
        // A read error thrown from here would tell the user nothing was changed, after the
        // write. Labels are not compared: the Dock rewrites them in the system language.
        guard let current = try? read() else { return false }
        return current.apps.map(\.id) == wanted.apps.map(\.id)
            && current.settings == wanted.settings
    }

    private func read(from store: DockPreferenceStore) throws(DockError) -> DockState {
        do {
            return try DockReader(store: store).read()
        } catch {
            throw .read(error)
        }
    }

    private func write(_ state: DockState, to store: DockPreferenceStore) throws(DockError) {
        do {
            try DockWriter(store: store).write(state)
        } catch {
            throw .write(error)
        }
    }

    private func restart() throws(DockError) {
        do {
            try restarter.restart()
        } catch {
            throw .restart(error)
        }
    }
}
