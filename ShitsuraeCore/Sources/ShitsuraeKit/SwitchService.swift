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

    public func apply(_ layout: DockLayout) throws {
        try engine.apply(layout.dockState(skippingMissing: .default))
        lastAppliedLayoutID = layout.id
    }

    public func readCurrentState() throws -> DockState {
        try engine.read()
    }
}
