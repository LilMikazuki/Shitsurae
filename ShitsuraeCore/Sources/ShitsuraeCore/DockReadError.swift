import Foundation

/// Провал разбора домена. Появление любой из этих ошибок означает,
/// что писать в домен нельзя: возможно, macOS сменила формат.
public enum DockReadError: Error, Equatable {
    /// Ключ есть, но лежит не то, что мы умеем понимать.
    case wrongType(key: String, expected: String)
    /// Элемент `persistent-apps` не разобрался.
    case malformedTile(index: Int, reason: String)
    /// Тип значения верный, но само значение не из тех, что мы понимаем.
    /// Отдельно от `wrongType`: тот, кто читает сообщение, разбирается,
    /// почему приложение отказалось работать с его Dock, и разница
    /// «формат сменился» против «значение непривычное» для него существенна.
    case unsupportedValue(key: String, value: String)
    /// Тайл разобрался, но его тип мы не поддерживаем. В v1 это разделители
    /// (`spacer-tile`, `small-spacer-tile`, `flex-spacer-tile`) — настоящая
    /// возможность Dock, а не порча формата. Отдельный случай нужен, чтобы
    /// интерфейс мог сказать пользователю правду о причине.
    case unsupportedTileType(index: Int, tileType: String)
}

extension DockReadError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .wrongType(key, expected):
            "Key \"\(key)\" holds an unexpected type, expected \(expected)."
        case let .malformedTile(index, reason):
            "Dock item #\(index) could not be parsed: \(reason)."
        case let .unsupportedValue(key, value):
            "Key \"\(key)\" holds an unsupported value: \(value)."
        case let .unsupportedTileType(index, tileType):
            "Dock item #\(index) is a \"\(tileType)\", which Shitsurae does not support yet."
        }
    }
}
