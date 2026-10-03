import Foundation
import ShitsuraeCore

public protocol DockApplying: Sendable {
    func read() throws(DockError) -> DockState
    @discardableResult func apply(_ state: DockState) throws(DockError) -> DockApplyOutcome
    @discardableResult func applyIfNeeded(_ state: DockState) throws(DockError) -> DockApplyOutcome
}

extension DockEngine: DockApplying {}
