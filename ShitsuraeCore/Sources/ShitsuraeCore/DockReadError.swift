import Foundation

/// Провал разбора домена. Появление любой из этих ошибок означает,
/// что писать в домен нельзя: возможно, macOS сменила формат.
public enum DockReadError: Error, Equatable {
    /// Ключ есть, но лежит не то, что мы умеем понимать.
    case wrongType(key: String, expected: String)
    /// Элемент `persistent-apps` не разобрался.
    case malformedTile(index: Int, reason: String)
}

extension DockReadError: CustomStringConvertible {
    public var description: String {
        switch self {
        case let .wrongType(key, expected):
            "Key \"\(key)\" holds an unexpected type, expected \(expected)."
        case let .malformedTile(index, reason):
            "Dock item #\(index) could not be parsed: \(reason)."
        }
    }
}
