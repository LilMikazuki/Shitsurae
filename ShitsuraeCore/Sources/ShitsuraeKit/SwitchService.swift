import Foundation
import ShitsuraeCore

public final class SwitchService: Sendable {
    private let engine: DockApplying

    public init(engine: DockApplying) {
        self.engine = engine
    }

    public func apply(_ layout: DockLayout) throws(DockError) {
        try engine.apply(layout.dockState(skippingMissing: .default))
    }

    @discardableResult
    public func applyIfNeeded(_ layout: DockLayout) throws(DockError) -> Bool {
        try engine.applyIfNeeded(layout.dockState(skippingMissing: .default))
    }

    public func readCurrentState() throws(DockError) -> DockState {
        try engine.read()
    }
}
