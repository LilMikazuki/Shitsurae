import ShitsuraeCore
import Foundation

let usage = """
Usage: shitsurae-cli <command>

Commands:
  dump                     Print the current Dock layout and settings
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

let arguments = Array(CommandLine.arguments.dropFirst())

switch arguments.first {
case "dump":
    do {
        print(DockStateFormatter.plainText(try DockEngine.live().read()))
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
    guard arguments.count >= 2 else { fail(usage) }
    let dryRun = arguments.contains("--dry-run")
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[1]))
        let state = try JSONDecoder().decode(DockState.self, from: data)
        if dryRun {
            // Пишем в память и читаем обратно — настоящий Dock не трогаем.
            let sandbox = InMemoryDockStore([:])
            DockWriter(store: sandbox).write(state)
            print("Dry run, the Dock was not touched:")
            print(DockStateFormatter.plainText(try DockReader(store: sandbox).read()))
        } else {
            try DockEngine.live().apply(state)
            print("Applied. The Dock is restarting.")
        }
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
