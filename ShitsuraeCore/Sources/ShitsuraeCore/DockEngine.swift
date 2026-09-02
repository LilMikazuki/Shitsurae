import Foundation

public struct DockEngine: Sendable {
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

    public func apply(_ state: DockState) throws(DockError) {
        _ = try read()
        try write(state, to: store)
        try restart()
    }

    @discardableResult
    public func applyIfNeeded(_ state: DockState) throws(DockError) -> Bool {
        let current = try read()
        guard try preview(state) != current else { return false }
        try write(state, to: store)
        try restart()
        return true
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
