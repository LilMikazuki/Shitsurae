import Foundation
import ShitsuraeCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

/// Подсказку по запросу печатаем в stdout, а при ошибке — в stderr.
func printUsage(asError: Bool) {
    if asError {
        FileHandle.standardError.write(Data("\(ShitsuraeCommand.usage)\n".utf8))
    } else {
        print(ShitsuraeCommand.usage)
    }
}

let jsonEncoder: JSONEncoder = {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    return encoder
}()

let command: ShitsuraeCommand
do {
    command = try ShitsuraeCommand.parse(Array(CommandLine.arguments.dropFirst()))
} catch CommandParseError.noCommand, CommandParseError.unknownCommand {
    // Запуск без команды — это не успех: скрипт с `if shitsurae-cli; then`
    // иначе принял бы «ничего не сделано» за удачу.
    printUsage(asError: true)
    exit(1)
} catch {
    fail("\(error)")
}

switch command {
case let .dump(json):
    do {
        let state = try DockEngine.live().read()
        if json {
            try print(String(decoding: jsonEncoder.encode(state), as: UTF8.self))
        } else {
            print(DockStateFormatter.plainText(state))
        }
    } catch {
        fail("Failed to read the Dock: \(error)")
    }

case .backup:
    do {
        let backup = DockBackup(directory: DockBackup.defaultDirectory)
        let created = try backup.createIfNeeded()
        print(created
            ? "Backup written to \(backup.backupURL.path)"
            : "Backup already exists at \(backup.backupURL.path)")
    } catch {
        fail("Failed to back up the Dock domain: \(error)")
    }

case let .apply(file, dryRun):
    do {
        let data = try Data(contentsOf: URL(fileURLWithPath: file))
        let state = try JSONDecoder().decode(DockState.self, from: data)
        if dryRun {
            print("Dry run, the Dock was not touched:")
            try print(DockStateFormatter.plainText(DockEngine.live().preview(state)))
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

case .help:
    printUsage(asError: false)
}
