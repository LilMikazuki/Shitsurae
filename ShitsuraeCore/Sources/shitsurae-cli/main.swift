import Foundation
import ShitsuraeCore

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(Data("\(message)\n".utf8))
    exit(1)
}

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
} catch CommandParseError.noCommand {
    printUsage(asError: true)
    exit(1)
} catch let error as CommandParseError {
    if case .unknownCommand = error {
        FileHandle.standardError.write(Data("\(error)\n".utf8))
        printUsage(asError: true)
        exit(1)
    }
    fail("\(error)")
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
            print("Applied. The Dock will pick it up.")
        }
    } catch let error as DockRestartError {
        fail("""
        The Dock layout was written, but the Dock did not restart: \(error)
        Run `killall Dock` to finish applying it.
        """)
    } catch {
        fail("Failed to apply: \(error)")
    }

case .restore:
    do {
        let backup = DockBackup(directory: DockBackup.defaultDirectory)
        try backup.restore()
        try DockRestarter().restart()
        print("Dock restored from \(backup.backupURL.path)")
    } catch let error as DockRestartError {
        fail("""
        The Dock domain was restored, but the Dock did not restart: \(error)
        Run `killall Dock` to finish applying it.
        """)
    } catch {
        fail("Failed to restore: \(error)")
    }

case .help:
    printUsage(asError: false)
}
