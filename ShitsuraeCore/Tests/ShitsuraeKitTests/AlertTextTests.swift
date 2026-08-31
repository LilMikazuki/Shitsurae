import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private func sample(of failure: ShitsuraeFailure) -> ShitsuraeFailure {
    switch failure {
    case .unreadableLayout: .unreadableLayout
    case .unsupportedSetting: .unsupportedSetting(key: "orientation", value: "diagonal")
    case .unsupportedTile: .unsupportedTile("spacer-tile")
    case .backupFailed: .backupFailed
    case .writeFailed: .writeFailed
    case let .writtenButNotApplied(stage): .writtenButNotApplied(stage)
    case .restoreFailed: .restoreFailed
    }
}

private let everyFailure: [ShitsuraeFailure] = [
    .unreadableLayout,
    .unsupportedSetting(key: "", value: ""),
    .unsupportedTile(""),
    .backupFailed,
    .writeFailed,
    .writtenButNotApplied(.restartRefused),
    .writtenButNotApplied(.writeIncomplete),
    .restoreFailed
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
    #expect(!ShitsuraeAlertKind.restore.isDestructive)
    #expect(!ShitsuraeAlertKind.failure(.writeFailed).isDestructive)

    #expect(ShitsuraeAlertKind.restore.hasCancel)
    #expect(ShitsuraeAlertKind.delete(id: UUID(), name: "Work").hasCancel)
    #expect(!ShitsuraeAlertKind.failure(.writeFailed).hasCancel)
}

@Test func theDeleteAlertNamesTheLayout() {
    #expect(ShitsuraeAlertKind.delete(id: UUID(), name: "Personal").title.contains("Personal"))
}

@Test func everyReasonThrownAfterTheDomainIsWrittenAdmitsIt() {
    let afterTheWrite: [any Error] = [
        DockBackupError.importFailed(status: 1),
        DockBackupError.importDidNotApply,
        DockRestartError.terminateRefused
    ]
    for error in afterTheWrite {
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

    #expect(ShitsuraeFailure(from: DockBackupError.backupMissing) == .restoreFailed)
    #expect(ShitsuraeFailure(from: DockBackupError.exportFailed(status: 1)) == .backupFailed)
}

@Test func aFailedRestoreDoesNotTellTheUserToRestartTheDock() {
    let failed = ShitsuraeFailure.writtenButNotApplied(.writeIncomplete)
    let text = (failed.title + " " + failed.message).lowercased()

    #expect(!text.contains("killall"), "restarting the Dock would entrench the failed restore")
    #expect(!text.contains("saved"), "a restore saves nothing")
    #expect(text.contains("restored"))
}

@Test func aFailedRestartStillSaysHowToFinish() {
    let refused = ShitsuraeFailure.writtenButNotApplied(.restartRefused)
    #expect(refused.message.contains("killall Dock"))
}

@Test func aLayoutThatCannotBeSavedIsNotReportedAsADockFailure() {
    let saveFailed = ShitsuraeAlertKind.saveFailed
    #expect(saveFailed.message.lowercased().contains("dock was not changed"))
    #expect(!saveFailed.hasCancel)
    #expect(!saveFailed.isDestructive)
}
