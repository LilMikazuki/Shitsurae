import Foundation

/// Провал записи в домен. Единственный сигнал успеха, который даёт
/// `CFPreferencesAppSynchronize`, — булев результат: если он `false`,
/// изменения не доехали до `cfprefsd`, и перезапускать Dock уже нельзя.
public enum DockWriteError: Error, Equatable {
    /// Синхронизация домена не удалась, записанное не сохранено.
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
