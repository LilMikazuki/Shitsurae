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

    public func read() throws -> DockState {
        try DockReader(store: store).read()
    }

    public func preview(_ state: DockState) throws -> DockState {
        _ = try read()

        var seed: [String: Any] = [:]
        for key in DockKey.all {
            if let value = store.value(forKey: key) {
                seed[key] = value
            }
        }
        let sandbox = InMemoryDockStore(seed)
        try DockWriter(store: sandbox).write(state)
        return try DockReader(store: sandbox).read()
    }

    public func apply(_ state: DockState) throws {
        _ = try read()
        try DockWriter(store: store).write(state)
        try restarter.restart()
    }

    @discardableResult
    public func applyIfNeeded(_ state: DockState) throws -> Bool {
        let current = try read()
        guard try preview(state) != current else { return false }
        try DockWriter(store: store).write(state)
        try restarter.restart()
        return true
    }
}
