import Foundation
import ShitsuraeCore

public protocol DockApplying: Sendable {
    func read() throws -> DockState
    func apply(_ state: DockState) throws
    @discardableResult func applyIfNeeded(_ state: DockState) throws -> Bool
}

extension DockEngine: DockApplying {}
