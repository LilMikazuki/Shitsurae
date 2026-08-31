import Foundation

public enum DockReadError: Error, Equatable {
    case wrongType(key: String, expected: String)
    case malformedTile(index: Int, reason: String)
    case unsupportedValue(key: String, value: String)
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
