import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func sample(of failure: ShitsuraeFailure) -> ShitsuraeFailure {
    switch failure {
    case .unreadableLayout: .unreadableLayout
    case .unsupportedSetting: .unsupportedSetting(key: "orientation", value: "diagonal")
    case .unsupportedTile: .unsupportedTile("spacer-tile")
    case .writeFailed: .writeFailed
    case .writtenButNotApplied: .writtenButNotApplied
    }
}

private let everyFailure: [ShitsuraeFailure] = [
    .unreadableLayout,
    .unsupportedSetting(key: "", value: ""),
    .unsupportedTile(""),
    .writeFailed,
    .writtenButNotApplied
].map(sample(of:))

@Test func onlyWrittenButNotAppliedAdmitsTheDockChanged() {
    for failure in everyFailure {
        let saysNothingChanged = failure.message.lowercased().contains("was not changed")
            || failure.message.lowercased().contains("nothing was changed")
        switch failure {
        case .writtenButNotApplied:
            #expect(!saysNothingChanged, "the Dock did change; the message must not deny it")
        case .writeFailed:
            #expect(!saysNothingChanged, "the values were set before the write refused; say maybe")
        default:
            #expect(saysNothingChanged, "\(failure) leaves the Dock untouched and must say so")
        }
    }
}

@Test func everyFailureHasATitleAndAMessage() {
    for failure in everyFailure {
        #expect(!failure.title.isEmpty)
        #expect(!failure.message.isEmpty)
        #expect(!failure.title.hasSuffix("."), "titles are headlines, not sentences")
    }
}

@Test func onlyDeletionIsDestructiveAndFailuresHaveNoCancel() {
    #expect(ShitsuraeAlertKind.delete(id: UUID(), name: "Work").isDestructive)
    #expect(!ShitsuraeAlertKind.saveFailed.isDestructive)
    #expect(!ShitsuraeAlertKind.failure(.writeFailed).isDestructive)

    #expect(ShitsuraeAlertKind.delete(id: UUID(), name: "Work").hasCancel)
    #expect(!ShitsuraeAlertKind.saveFailed.hasCancel)
    #expect(!ShitsuraeAlertKind.failure(.writeFailed).hasCancel)
}

@Test func theDeleteAlertNamesTheLayout() {
    #expect(ShitsuraeAlertKind.delete(id: UUID(), name: "Personal").title.contains("Personal"))
}

@Test func everyReasonThrownAfterTheDomainIsWrittenAdmitsIt() {
    let error = DockRestartError.terminateRefused
    let admitsTheChange = if case .writtenButNotApplied = ShitsuraeFailure(from: error) {
        true
    } else {
        false
    }
    #expect(
        admitsTheChange,
        "\(error) is thrown after the Dock domain was rewritten, so the message must not deny it"
    )
}

@Test func aFailedRestartStillSaysHowToFinish() {
    let refused = ShitsuraeFailure.writtenButNotApplied
    #expect(refused.message.contains("killall Dock"))
}

@Test func aLayoutThatCannotBeSavedIsNotReportedAsADockFailure() {
    let saveFailed = ShitsuraeAlertKind.saveFailed
    #expect(saveFailed.message.lowercased().contains("dock was not changed"))
    #expect(!saveFailed.hasCancel)
    #expect(!saveFailed.isDestructive)
}
