import Foundation

public enum DockWriteError: Error, Equatable {
    case synchronizeFailed
}

extension DockWriteError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .synchronizeFailed:
            "The Dock preferences could not be saved: the preferences daemon rejected the write."
        }
    }
}
