public enum DockError: Error, Equatable {
    case read(DockReadError)
    case write(DockWriteError)
    case restart(DockRestartError)
}

extension DockError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .read(error): error.description
        case let .write(error): error.description
        case let .restart(error): error.description
        }
    }
}
