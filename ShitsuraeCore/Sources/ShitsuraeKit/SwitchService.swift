import Foundation
import ShitsuraeCore

public final class SwitchService: Sendable {
    private let engine: DockApplying
    private let marker: ActiveLayoutMarker

    public init(engine: DockApplying, defaults: UserDefaults = .standard) {
        self.engine = engine
        marker = ActiveLayoutMarker(defaults: defaults)
    }

    public var lastAppliedLayoutID: UUID? {
        get { marker.id }
        set { marker.id = newValue }
    }

    public func apply(_ layout: DockLayout) throws(DockError) {
        try engine.apply(layout.dockState(skippingMissing: .default))
        lastAppliedLayoutID = layout.id
    }

    @discardableResult
    public func applyIfNeeded(_ layout: DockLayout) throws(DockError) -> Bool {
        let wrote = try engine.applyIfNeeded(layout.dockState(skippingMissing: .default))
        lastAppliedLayoutID = layout.id
        return wrote
    }

    public func readCurrentState() throws(DockError) -> DockState {
        try engine.read()
    }
}
