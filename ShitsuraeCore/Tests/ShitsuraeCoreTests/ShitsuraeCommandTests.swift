import Foundation
@testable import ShitsuraeCore
import Testing

@Test func parsesSimpleCommands() throws {
    #expect(try ShitsuraeCommand.parse(["dump"]) == .dump(json: false))
    #expect(try ShitsuraeCommand.parse(["dump", "--json"]) == .dump(json: true))
    #expect(try ShitsuraeCommand.parse(["--help"]) == .help)
    #expect(try ShitsuraeCommand.parse(["-h"]) == .help)
}

@Test func parsesApply() throws {
    #expect(try ShitsuraeCommand.parse(["apply", "s.json"]) == .apply(
        file: "s.json",
        dryRun: false
    ))
    #expect(try ShitsuraeCommand.parse(["apply", "s.json", "--dry-run"])
        == .apply(file: "s.json", dryRun: true))
}

@Test func aTypoInTheApplyFlagIsRejected() {
    for typo in ["--dryrun", "--dry_run", "-dry-run", "--DRY-RUN", "--dry-run=yes"] {
        #expect(throws: CommandParseError.self) {
            try ShitsuraeCommand.parse(["apply", "s.json", typo])
        }
    }
}

@Test func aTypoInTheDumpFlagIsRejected() {
    for typo in ["--jsn", "--JSON", "-json"] {
        #expect(throws: CommandParseError.self) {
            try ShitsuraeCommand.parse(["dump", typo])
        }
    }
}

@Test func anExtraArgumentIsRejected() {
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["dump", "--json", "x"]) }
    #expect(throws: CommandParseError.self) {
        try ShitsuraeCommand.parse(["apply", "s.json", "--dry-run", "x"])
    }
}

@Test func applyingWithoutAFileIsRejected() {
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse(["apply"]) }
}

@Test func emptyInputAndAnUnknownCommandDiffer() {
    #expect(throws: CommandParseError.noCommand) { try ShitsuraeCommand.parse([]) }
    #expect(throws: CommandParseError.unknownCommand("frobnicate")) {
        try ShitsuraeCommand.parse(["frobnicate"])
    }
}

@Test func theParseErrorTextsArePinned() {
    #expect("\(CommandParseError.missingFile)"
        == "apply requires a file argument. Usage: apply <file> [--dry-run]")
    #expect(
        "\(CommandParseError.unrecognizedArguments(command: "apply", arguments: ["--dryrun"], usage: "apply <file> [--dry-run]"))"
            == "Unrecognized argument(s) for apply: --dryrun. Usage: apply <file> [--dry-run]"
    )
}

@Test func usageRejectsTrailingArguments() {
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["--help", "extra"]) }
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["-h", "junk"]) }
}

@Test func aFlagInsteadOfAFilenameIsAMissingFile() {
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse([
        "apply",
        "--dry-run"
    ]) }
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse(["apply", "-h"]) }
}

@Test func theUsageTextNamesEveryCommand() {
    for name in ["dump", "apply", "--help"] {
        #expect(ShitsuraeCommand.usage.contains(name))
    }
}

@Test func theRemovedCommandsAreNotAccepted() {
    #expect(throws: CommandParseError.unknownCommand("backup")) {
        try ShitsuraeCommand.parse(["backup"])
    }
    #expect(throws: CommandParseError.unknownCommand("restore")) {
        try ShitsuraeCommand.parse(["restore"])
    }
}
