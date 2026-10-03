import Foundation
import ShitsuraeCore

public final class SwitchService: Sendable {
    private let engine: DockApplying

    public init(engine: DockApplying) {
        self.engine = engine
    }

    @discardableResult
    public func apply(_ layout: DockLayout) throws(DockError) -> DockApplyOutcome {
        try engine.apply(layout.dockState(skippingMissing: .default))
    }

    @discardableResult
    public func applyIfNeeded(_ layout: DockLayout) throws(DockError) -> DockApplyOutcome {
        try engine.applyIfNeeded(layout.dockState(skippingMissing: .default))
    }

    public func readCurrentState() throws(DockError) -> DockState {
        try engine.read()
    }
}
