import Foundation
@testable import ShitsuraeCore
import Testing

@Test func разбираетПростыеКоманды() throws {
    #expect(try ShitsuraeCommand.parse(["dump"]) == .dump(json: false))
    #expect(try ShitsuraeCommand.parse(["dump", "--json"]) == .dump(json: true))
    #expect(try ShitsuraeCommand.parse(["backup"]) == .backup)
    #expect(try ShitsuraeCommand.parse(["--help"]) == .help)
    #expect(try ShitsuraeCommand.parse(["-h"]) == .help)
}

@Test func разбираетПрименение() throws {
    #expect(try ShitsuraeCommand.parse(["apply", "s.json"]) == .apply(
        file: "s.json",
        dryRun: false
    ))
    #expect(try ShitsuraeCommand.parse(["apply", "s.json", "--dry-run"])
        == .apply(file: "s.json", dryRun: true))
}

/// Главный тест файла. Опечатка в флаге обязана отвергаться, а не молча
/// превращаться в настоящее применение к Dock пользователя.
@Test func опечаткаВФлагеПримененияОтвергается() {
    for typo in ["--dryrun", "--dry_run", "-dry-run", "--DRY-RUN", "--dry-run=yes"] {
        #expect(throws: CommandParseError.self) {
            try ShitsuraeCommand.parse(["apply", "s.json", typo])
        }
    }
}

@Test func опечаткаВФлагеДампаОтвергается() {
    for typo in ["--jsn", "--JSON", "-json"] {
        #expect(throws: CommandParseError.self) {
            try ShitsuraeCommand.parse(["dump", typo])
        }
    }
}

@Test func лишнийАргументОтвергается() {
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["dump", "--json", "x"]) }
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["backup", "x"]) }
    #expect(throws: CommandParseError.self) {
        try ShitsuraeCommand.parse(["apply", "s.json", "--dry-run", "x"])
    }
}

@Test func применениеБезФайлаОтвергается() {
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse(["apply"]) }
}

@Test func пустойВводИНеизвестнаяКомандаРазличаются() {
    #expect(throws: CommandParseError.noCommand) { try ShitsuraeCommand.parse([]) }
    #expect(throws: CommandParseError.unknownCommand("frobnicate")) {
        try ShitsuraeCommand.parse(["frobnicate"])
    }
}

/// Тексты видит пользователь, поэтому закреплены дословно.
@Test func текстыОшибокРазбораЗакреплены() {
    #expect("\(CommandParseError.missingFile)"
        == "apply requires a file argument. Usage: apply <file> [--dry-run]")
    #expect(
        "\(CommandParseError.unrecognizedArguments(command: "apply", arguments: ["--dryrun"], usage: "apply <file> [--dry-run]"))"
            == "Unrecognized argument(s) for apply: --dryrun. Usage: apply <file> [--dry-run]"
    )
}

/// `--help` отвергает мусор так же, как остальные команды. Это осознанное
/// расхождение с прежним поведением, где хвостовые аргументы молча
/// игнорировались: молча съеденный аргумент — ровно тот класс дефекта,
/// из-за которого `--dryrun` когда-то выполнял настоящее применение.
@Test func подсказкаОтвергаетХвостовыеАргументы() {
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["--help", "extra"]) }
    #expect(throws: CommandParseError.self) { try ShitsuraeCommand.parse(["-h", "junk"]) }
}

/// Забытое имя файла не должно съедаться флагом: иначе `apply --dry-run`
/// уходит на путь настоящего применения и спасает только то, что файла
/// с таким именем не существует.
@Test func флагВместоИмениФайлаЭтоОтсутствующийФайл() {
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse([
        "apply",
        "--dry-run"
    ]) }
    #expect(throws: CommandParseError.missingFile) { try ShitsuraeCommand.parse(["apply", "-h"]) }
}

@Test func разбираетВосстановление() throws {
    #expect(try ShitsuraeCommand.parse(["restore"]) == .restore)
}

/// `restore` разрушительнее `apply`: он затирает раскладку целиком.
/// Молча съеденный аргумент здесь стоил бы дороже всего.
@Test func мусорПослеВосстановленияОтвергается() {
    for junk in ["--dryrun", "--dry-run", "x"] {
        #expect(throws: CommandParseError.self) {
            try ShitsuraeCommand.parse(["restore", junk])
        }
    }
}
