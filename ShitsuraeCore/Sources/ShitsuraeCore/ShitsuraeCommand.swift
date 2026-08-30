import Foundation

/// Провал разбора командной строки. Тексты английские: их видит пользователь.
public enum CommandParseError: Error, Equatable {
    /// Программу запустили без команды.
    case noCommand
    /// Первым аргументом пришло что-то, чего мы не знаем.
    case unknownCommand(String)
    /// `apply` вызван без пути к файлу.
    case missingFile
    /// Команда узнана, но хвост аргументов не разобран.
    case unrecognizedArguments(command: String, arguments: [String], usage: String)
}

extension CommandParseError: CustomStringConvertible {
    public var description: String {
        switch self {
        case .noCommand:
            "No command given."
        case let .unknownCommand(name):
            "Unknown command: \(name)."
        case .missingFile:
            "apply requires a file argument. Usage: apply <file> [--dry-run]"
        case let .unrecognizedArguments(command, arguments, usage):
            "Unrecognized argument(s) for \(command): "
                + "\(arguments.joined(separator: " ")). Usage: \(usage)"
        }
    }
}

/// Разобранная команда. Живёт в библиотеке, а не в `main.swift`, потому что
/// проверка формы аргументов — единственное, что стоит между опечаткой в
/// `--dry-run` и настоящей перезаписью Dock, и она обязана быть под тестами.
public enum ShitsuraeCommand: Equatable, Sendable {
    case dump(json: Bool)
    case backup
    case apply(file: String, dryRun: Bool)
    case help

    public static let usage = """
    Usage: shitsurae-cli <command>

    Commands:
      dump [--json]            Print the current Dock layout and settings;
                               --json prints a DockState JSON document instead
      backup                   Create the one-time backup of the Dock domain
      apply <file> [--dry-run] Apply a DockState JSON file; --dry-run prints the
                               result without touching the real Dock
      --help, -h               Print this message
    """

    public static func parse(_ arguments: [String]) throws -> ShitsuraeCommand {
        guard let command = arguments.first else { throw CommandParseError.noCommand }
        let rest = Array(arguments.dropFirst())

        switch command {
        case "dump":
            switch rest {
            case []: return .dump(json: false)
            case ["--json"]: return .dump(json: true)
            default:
                throw CommandParseError.unrecognizedArguments(
                    command: "dump", arguments: rest, usage: "dump [--json]")
            }

        case "backup":
            guard rest.isEmpty else {
                throw CommandParseError.unrecognizedArguments(
                    command: "backup", arguments: rest, usage: "backup")
            }
            return .backup

        case "apply":
            guard let file = rest.first, !file.hasPrefix("-") else {
                throw CommandParseError.missingFile
            }
            switch Array(rest.dropFirst()) {
            case []: return .apply(file: file, dryRun: false)
            case ["--dry-run"]: return .apply(file: file, dryRun: true)
            case let extra:
                throw CommandParseError.unrecognizedArguments(
                    command: "apply", arguments: extra, usage: "apply <file> [--dry-run]")
            }

        case "--help", "-h":
            guard rest.isEmpty else {
                throw CommandParseError.unrecognizedArguments(
                    command: command, arguments: rest, usage: "--help")
            }
            return .help

        default:
            throw CommandParseError.unknownCommand(command)
        }
    }
}
