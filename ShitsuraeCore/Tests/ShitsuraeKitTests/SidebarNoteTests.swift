import Foundation
@testable import ShitsuraeKit
import Testing

private func duplicate(_ name: String, of layout: String) -> DuplicateLayoutFile {
    DuplicateLayoutFile(name: name, layoutName: layout)
}

@Test func aFolderWithNothingWrongSaysNothing() {
    #expect(SidebarNote.duplicates([]) == nil)
    #expect(SidebarNote.unreadable([]) == nil)
}

@Test func oneExtraCopyNamesTheLayoutItBelongsTo() throws {
    let note = try #require(SidebarNote.duplicates([duplicate("Work copy.json", of: "Work")]))

    #expect(note.contains("Work"))
    #expect(!note.contains("Work copy.json"))
    #expect(!note.contains("(s)"))
}

@Test func extraCopiesOfSeveralLayoutsCountTheLayoutsNotTheFiles() throws {
    let note = try #require(SidebarNote.duplicates([
        duplicate("a.json", of: "Work"),
        duplicate("b.json", of: "Work"),
        duplicate("c.json", of: "Personal")
    ]))

    #expect(note.contains("2 layouts"))
}

@Test func aNoteAboutOneFileIsNotWrittenInThePlural() throws {
    let one = try #require(SidebarNote.unreadable(["broken.json"]))
    let two = try #require(SidebarNote.unreadable(["broken.json", "worse.json"]))

    #expect(one.contains("A file"))
    #expect(two.contains("2 files"))
    #expect(!one.contains("(s)"))
    #expect(!two.contains("(s)"))
}

@Test func everyNoteSaysWhatBecameOfTheFile() throws {
    let notes = try [
        #require(SidebarNote.duplicates([duplicate("Work copy.json", of: "Work")])),
        #require(SidebarNote.unreadable(["broken.json"]))
    ]

    for note in notes {
        #expect(note.contains("isn't used") || note.contains("skipped"))
    }
}
