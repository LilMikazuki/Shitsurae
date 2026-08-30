import Foundation
import ShitsuraeCore

let usage = """
Usage: shitsurae-cli <command>

Commands:
  dump [--json]            Print the current Dock layout and settings;
                           --json prints a DockState JSON document instead
  backup                   Create the one-time backup of the Dock domain
  apply <file> [--dry-run] Apply a DockState JSON file; --dry-run prints the
                           result without touching the real Dock
  --help, -h               Print this message
"""

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

/// Подсказку по запросу печатаем в stdout, а при ошибке — в stderr.
func printUsage(asError: Bool) {
    if asError {
        FileHandle.standardError.write(Data("\(usage)\n".utf8))
    } else {
        print(usage)
    }
}

/// Снимок текущих значений домена по нашим семи ключам. Используется как
/// стартовое состояние песочницы `--dry-run`: чтение из настоящего домена
/// безопасно, мы избегаем только записи в него.
func currentDomainSnapshot() -> [String: Any] {
    let source = CFPreferencesDockStore()
    var snapshot: [String: Any] = [:]
    for key in DockKey.all {
        if let value = source.value(forKey: key) {
            snapshot[key] = value
        }
    }
    return snapshot
}

let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}()

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "dump":
    let asJSON: Bool
    switch Array(arguments.dropFirst()) {
    case []:
        asJSON = false
    case ["--json"]:
        asJSON = true
    case let extra:
        fail(
            "Unrecognized argument(s) for dump: \(extra.joined(separator: " ")). Usage: dump [--json]"
        )
    }
    do {
        let state = try DockEngine.live().read()
        if asJSON {
            try print(String(decoding: jsonEncoder.encode(state), as: UTF8.self))
        } else {
            print(DockStateFormatter.plainText(state))
        }
    } catch {
        fail("Failed to read the Dock: \(error)")
    }

case "backup":
    do {
        let backup = DockBackup(directory: DockBackup.defaultDirectory)
        let created = try backup.createIfNeeded()
        print(created
            ? "Backup written to \(backup.backupURL.path)"
            : "Backup already exists at \(backup.backupURL.path)")
    } catch {
        fail("Failed to back up the Dock domain: \(error)")
    }

case "apply":
    guard arguments.count >= 2 else {
        fail("apply requires a file argument. Usage: apply <file> [--dry-run]")
    }
    let file = arguments[1]
    let dryRun: Bool
    switch Array(arguments.dropFirst(2)) {
    case []:
        dryRun = false
    case ["--dry-run"]:
        dryRun = true
    case let extra:
        fail(
            "Unrecognized argument(s) for apply: \(extra.joined(separator: " ")). Usage: apply <file> [--dry-run]"
        )
    }
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        let state = try JSONDecoder().decode(DockState.self, from: data)
        if dryRun {
            // Затравка — текущий домен, а не пустой словарь: иначе настройки,
            // пропущенные во входном файле, выглядели бы так, будто сбросятся
            // на дефолт, хотя на самом деле останутся как есть. Пишем поверх
            // состояние из файла — настоящий Dock всё равно не трогаем.
            let sandbox = InMemoryDockStore(currentDomainSnapshot())
            DockWriter(store: sandbox).write(state)
            print("Dry run, the Dock was not touched:")
            try print(DockStateFormatter.plainText(DockReader(store: sandbox).read()))
        } else {
            try DockEngine.live().apply(state)
            print("Applied. The Dock is restarting.")
        }
    } catch let error as DockRestartError {
        // К этому моменту домен уже записан и бэкап уже существует — молчать
        // об этом или мешать с обычной ошибкой было бы нечестно с пользователем.
        fail("""
        The Dock layout was written, but the Dock did not restart: \(error)
        Run `killall Dock` to finish applying it.
        """)
    } catch {
        fail("Failed to apply: \(error)")
    }

case "--help", "-h":
    printUsage(asError: false)

default:
    // Запуск без команды — это не успех: скрипт с `if shitsurae-cli; then`
    // иначе принял бы «ничего не сделано» за удачу.
    printUsage(asError: true)
    exit(1)
}
