import Foundation
@testable import ShitsuraeKit
import Testing

@Test func noNoteWithoutAReason() {
    #expect(LayoutNote.make(missing: []) == nil)
}

@Test func missingAppsAreListedCommaSeparated() {
    let note = LayoutNote.make(missing: ["Figma", "Sketch"])
    #expect(note?.text == "Figma, Sketch not found on disk — will be skipped")
    #expect(note?.isWarning == true)
}

@Test func oneMissingAppIsNamedOnItsOwn() {
    #expect(LayoutNote.make(missing: ["Figma"])?
        .text == "Figma not found on disk — will be skipped")
}
