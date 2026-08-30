import ShitsuraeCore
import Foundation

let usage = """
Usage: shitsurae-cli <command>

Commands:
  dump    Print the current Dock layout and settings
"""

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
default:
    print(usage)
    exit(arguments.isEmpty ? 0 : 1)
}
