import Foundation
import ShitsuraeCore

public protocol DockApplying: Sendable {
    func read() throws -> DockState
    func apply(_ state: DockState) throws
}

extension DockEngine: DockApplying {}
