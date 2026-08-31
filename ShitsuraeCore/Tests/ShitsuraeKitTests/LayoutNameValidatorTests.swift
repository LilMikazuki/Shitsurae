@testable import ShitsuraeKit
import Testing

@Test func theDefaultNameIsNumberedFromTheLayoutCount() {
    #expect(LayoutNameValidator.defaultName(existingCount: 0) == "Layout 1")
    #expect(LayoutNameValidator.defaultName(existingCount: 2) == "Layout 3")
}

@Test func anEmptyNameIsAProblemWithoutText() {
    #expect(LayoutNameValidator.problem(for: "", existing: []) == .empty)
    #expect(LayoutNameValidator.problem(for: "   ", existing: []) == .empty)
    #expect(LayoutNameProblem.empty.message == nil)
}

@Test func duplicateDetectionIgnoresCaseAndWhitespace() {
    #expect(LayoutNameValidator.problem(for: "  work ", existing: ["Work"])
        == .duplicate("work"))
    #expect(LayoutNameValidator.problem(for: "WORK", existing: ["Work"])
        == .duplicate("WORK"))
}

@Test func theDuplicateErrorTextMatchesTheMockup() {
    #expect(LayoutNameProblem.duplicate("Work").message
        == "A layout named \"Work\" already exists.")
}

@Test func aFreeNameReportsNoProblem() {
    #expect(LayoutNameValidator.problem(for: "Focus", existing: ["Work", "Personal"]) == nil)
}

@Test func aLayoutsOwnNameIsNotADuplicateWhenRenaming() {
    #expect(LayoutNameValidator.problem(for: "Work", existing: []) == nil)
}
