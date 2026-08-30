import ShitsuraeCore
import Foundation

let usage = """
Usage: shitsurae-cli <command>

Commands:
  dump           Print the current Dock layout and settings
  --help, -h     Print this usage text
"""

/// Подсказку по запросу печатаем в stdout, а при ошибке — в stderr,
/// как и любое другое сообщение об ошибке в этом файле.
func printUsage(asError: Bool) {
    if asError {
        FileHandle.standardError.write(Data("\(usage)\n".utf8))
    } else {
        print(usage)
    }
}

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "dump":
    do {
        let state = try DockReader(store: CFPreferencesDockStore()).read()
        print(DockStateFormatter.plainText(state))
    } catch {
        FileHandle.standardError.write(Data("Failed to read the Dock: \(error)\n".utf8))
        exit(1)
    }
case "--help", "-h":
    printUsage(asError: false)
default:
    // Запуск без команды — это не успех: скрипт с `if shitsurae-cli; then`
    // иначе принял бы «ничего не сделано» за удачу.
    printUsage(asError: true)
    exit(1)
}
