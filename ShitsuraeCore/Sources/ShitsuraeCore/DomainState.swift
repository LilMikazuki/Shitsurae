/// What the Dock domain looks like by the time an error is thrown. It is a fact
/// about the throw site, so it lives beside the errors: a new case cannot be
/// added without the compiler asking which of these it is.
public enum DomainState: Equatable, Sendable {
    case untouched
    case uncertain
    case changed
}

public extension DockReadError {
    var domainState: DomainState {
        switch self {
        case .wrongType, .malformedTile, .unsupportedValue, .unsupportedTileType: .untouched
        }
    }
}

public extension DockBackupError {
    var domainState: DomainState {
        switch self {
        case .backupDirectoryUnavailable, .exportCouldNotStart, .exportFailed,
             .exportProducedInvalidFile, .backupMissing:
            .untouched
        case .importCouldNotStart, .importFailed, .importDidNotApply:
            .changed
        }
    }
}

public extension DockWriteError {
    var domainState: DomainState {
        switch self {
        case .synchronizeFailed: .uncertain
        }
    }
}

public extension DockRestartError {
    var domainState: DomainState {
        switch self {
        case .terminateRefused: .changed
        }
    }
}
