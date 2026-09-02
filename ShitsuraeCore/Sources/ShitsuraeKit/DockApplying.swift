import Foundation
import ShitsuraeCore

public protocol DockApplying: Sendable {
    func read() throws(DockError) -> DockState
    func apply(_ state: DockState) throws(DockError)
    @discardableResult func applyIfNeeded(_ state: DockState) throws(DockError) -> Bool
}

extension DockEngine: DockApplying {}
