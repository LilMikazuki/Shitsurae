import Foundation
import ShitsuraeCore
@testable import ShitsuraeKit
import Testing

private struct ThrowSite {
    let error: any Error
    let state: DomainState
    let site: String
}

private func throwSite(_ error: DockReadError, _ where_: String) -> ThrowSite {
    ThrowSite(error: error, state: error.domainState, site: where_)
}

private func throwSite(_ error: DockWriteError, _ where_: String) -> ThrowSite {
    ThrowSite(error: error, state: error.domainState, site: where_)
}

private func throwSite(_ error: DockRestartError, _ where_: String) -> ThrowSite {
    ThrowSite(error: error, state: error.domainState, site: where_)
}

/// Each family below is enumerated twice: once as a `CaseIterable` mirror that
/// supplies a sample and its domain state, and once as a switch from the real
/// error to that mirror. Adding an error case breaks the switch; adding a mirror
/// case breaks the sample. Neither compiles until the table has grown, which is
/// the whole point — a list that only sits beside an exhaustive switch can, and
/// did, fall behind it.
private protocol FailureFamily: CaseIterable, Equatable {
    var site: ThrowSite { get }
}

private enum ReadFailure: FailureFamily {
    case wrongType, malformedTile, unsupportedValue, unsupportedTileType

    var site: ThrowSite {
        let where_ = "DockReader, before any write"
        return switch self {
        case .wrongType:
            throwSite(DockReadError.wrongType(key: "tilesize", expected: "number"), where_)
        case .malformedTile:
            throwSite(DockReadError.malformedTile(index: 0, reason: "no tile-data"), where_)
        case .unsupportedValue:
            throwSite(DockReadError.unsupportedValue(key: "orientation", value: "diagonal"), where_)
        case .unsupportedTileType:
            throwSite(DockReadError.unsupportedTileType(index: 0, tileType: "spacer-tile"), where_)
        }
    }
}

private enum WriteFailure: FailureFamily {
    case synchronizeFailed

    var site: ThrowSite {
        switch self {
        case .synchronizeFailed:
            throwSite(
                DockWriteError.synchronizeFailed,
                "DockWriter.write, values already set, the flush was refused"
            )
        }
    }
}

private enum RestartFailure: FailureFamily {
    case terminateRefused

    var site: ThrowSite {
        switch self {
        case .terminateRefused:
            throwSite(
                DockRestartError.terminateRefused,
                "DockRestarter, after the domain was written"
            )
        }
    }
}

private func family(of error: DockReadError) -> ReadFailure {
    switch error {
    case .wrongType: .wrongType
    case .malformedTile: .malformedTile
    case .unsupportedValue: .unsupportedValue
    case .unsupportedTileType: .unsupportedTileType
    }
}

private func family(of error: DockWriteError) -> WriteFailure {
    switch error {
    case .synchronizeFailed: .synchronizeFailed
    }
}

private func family(of error: DockRestartError) -> RestartFailure {
    switch error {
    case .terminateRefused: .terminateRefused
    }
}

private let throwSites: [ThrowSite] =
    ReadFailure.allCases.map(\.site)
        + WriteFailure.allCases.map(\.site)
        + RestartFailure.allCases.map(\.site)

private func shown(_ failure: ShitsuraeFailure) -> String {
    (failure.title + " " + failure.message).lowercased()
}

private func deniesAnyChange(_ text: String) -> Bool {
    text.contains("nothing was changed") || text.contains("was not changed")
}

@Test func theTableCoversEveryFailureOnTheDockPath() {
    #expect(throwSites.count == 6)
}

@Test func noFailureDeniesAChangeItAlreadyMade() {
    for site in throwSites {
        let text = shown(ShitsuraeFailure(from: site.error))
        switch site.state {
        case .untouched:
            #expect(deniesAnyChange(text), "\(site.site): the Dock is untouched, so say so")
        case .uncertain:
            #expect(!deniesAnyChange(text), "\(site.site): the values were already set")
            #expect(
                text.contains("may"),
                "\(site.site): nothing is known to have persisted, so do not assert a change either"
            )
        case .changed:
            #expect(!deniesAnyChange(text), "\(site.site): the domain was written; do not deny it")
        }
    }
}

@Test func killallIsOnlyAdvisedWhenARunningDockRefusedToQuit() {
    for site in throwSites where shown(ShitsuraeFailure(from: site.error)).contains("killall") {
        #expect(
            ShitsuraeFailure(from: site.error) == .writtenButNotApplied,
            "\(site.site): restarting only finishes the job when a running Dock refused to quit"
        )
    }
}

@Test func everySampleBelongsToTheCaseThatSuppliedIt() throws {
    for kind in ReadFailure.allCases {
        #expect(try family(of: #require(kind.site.error as? DockReadError)) == kind)
    }
    for kind in WriteFailure.allCases {
        #expect(try family(of: #require(kind.site.error as? DockWriteError)) == kind)
    }
    for kind in RestartFailure.allCases {
        #expect(try family(of: #require(kind.site.error as? DockRestartError)) == kind)
    }
}
