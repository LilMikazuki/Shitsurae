import AppKit
import Foundation
import Observation
import ShitsuraeCore

/// Exactly one reason — `writtenButNotApplied` — means the Dock has already
/// changed. Merging it with the others would make the messages lie.
public enum ShitsuraeFailure: Equatable, Sendable {
    case unreadableLayout
    case unsupportedSetting(key: String, value: String)
    case unsupportedTile(String)
    case writeFailed
    case writtenButNotApplied

    public init(from error: DockError) {
        switch error {
        case let .read(error):
            switch error {
            case let .unsupportedTileType(_, tileType):
                self = .unsupportedTile(tileType)
            case let .unsupportedValue(key, value):
                self = .unsupportedSetting(key: key, value: value)
            case .wrongType, .malformedTile:
                self = .unreadableLayout
            }
        case .write:
            self = .writeFailed
        case .restart:
            self = .writtenButNotApplied
        }
    }
}

public enum SettingsPage: Hashable, Sendable {
    case layout(UUID)
    case general
}

public enum ShitsuraeAlertKind: Equatable, Sendable {
    case saveFailed
    case deleteFailed
    case delete(id: UUID, name: String)
    case failure(ShitsuraeFailure)
}

@MainActor
@Observable
public final class AppModel {
    public private(set) var layouts: [DockLayout] = []
    private var pageMirror: SettingsPage?

    public var page: SettingsPage? {
        get { pageMirror }
        set {
            pageMirror = newValue
            if let recording = shortcuts.recordingID, newValue != .layout(recording) {
                shortcuts.stop()
            }
        }
    }

    private var alerts: [ShitsuraeAlertKind] = []
    private var presenting = false

    public var alert: ShitsuraeAlertKind? {
        alerts.first
    }

    private let quitter: any AppQuitting
    private let log: any EventLog
    private let store: LayoutStore
    private let switcher: SwitchService
    private let marker: ActiveLayoutMarker
    public let shortcuts: ShortcutRecorder

    public init(
        store: LayoutStore,
        switcher: SwitchService,
        marker: ActiveLayoutMarker = ActiveLayoutMarker(),
        shortcuts: ShortcutRecorder = ShortcutRecorder(),
        quitter: any AppQuitting = WorkspaceAppQuitter(),
        log: any EventLog = SystemEventLog()
    ) {
        self.store = store
        self.switcher = switcher
        self.marker = marker
        self.shortcuts = shortcuts
        self.quitter = quitter
        self.log = log
        activeLayoutID = marker.id
    }

    /// A stored property, written only by `setActiveLayout`, which writes through
    /// to the marker. A computed property over `UserDefaults` would be invisible
    /// to observation and every view reading it would stop updating.
    public private(set) var activeLayoutID: UUID?

    public private(set) var unreadableFiles: [String] = []

    public private(set) var duplicateFiles: [DuplicateLayoutFile] = []

    public private(set) var storeUnavailable = false

    /// The Dock has one arrangement, so it gets one writer. Two applies in
    /// flight would interleave preference writes and leave the active mark
    /// describing whichever finished last.
    public private(set) var isChangingDock = false

    private func setActiveLayout(_ id: UUID?) {
        marker.id = id
        activeLayoutID = id
    }

    public var selectedLayout: DockLayout? {
        guard case let .layout(id) = page else { return nil }
        return layouts.first { $0.id == id }
    }

    public func reload() {
        do {
            let loaded = try store.load()
            layouts = loaded.layouts
            unreadableFiles = loaded.unreadable
            duplicateFiles = loaded.duplicates
            storeUnavailable = false
        } catch {
            storeUnavailable = true
            log.record(.error, .layouts, "Loading the layouts folder failed: \(error)")
        }
        listDidChange()
    }

    private func listDidChange() {
        switch page {
        case let .layout(id) where layouts.contains(where: { $0.id == id }):
            break
        case .general:
            break
        default:
            page = layouts.first.map { .layout($0.id) }
        }
        shortcuts.register(layouts.map(\.id))
    }

    private func replace(_ layout: DockLayout) {
        guard let index = layouts.firstIndex(where: { $0.id == layout.id }) else { return }
        layouts[index] = layout
    }

    public var layoutsFolder: URL {
        store.directory
    }

    public func refreshFromDisk() {
        store.adoptStrayFiles()
        reload()
    }

    public func apply(id: UUID) async {
        guard !isChangingDock else {
            log.record(.notice, .dock, "Applying \(id) dropped: another Dock change is in flight")
            return
        }
        guard let snapshot = layouts.first(where: { $0.id == id }) else { return }
        isChangingDock = true
        defer { isChangingDock = false }
        let switcher = switcher
        // The skip is allowed only for the already-active layout: the active mark is set only
        // after a successful apply including the restart, so after a refused restart there is no
        // mark and the retry takes the normal writing path.
        let reapplying = id == activeLayoutID
        do {
            let wrote = try await offMainThread { () throws(DockError) -> Bool in
                if reapplying {
                    return try switcher.applyIfNeeded(snapshot)
                }
                try switcher.apply(snapshot)
                return true
            }
            log.record(
                .notice, .dock,
                """
                Applied layout \(id): \
                \(snapshot.dockState(skippingMissing: .default).apps.count) tiles, \
                \(wrote ? "the Dock was written" : "the Dock already held it")
                """
            )
            if snapshot.quitsOtherApps {
                quitOthers(for: snapshot)
            }
            if case .layout = page {
                page = .layout(id)
            }
            if var fresh = layouts.first(where: { $0.id == id }),
               fresh.dockState == snapshot.dockState
            {
                setActiveLayout(id)
                fresh.lastUsedAt = Date()
                do {
                    try store.save(fresh)
                    replace(fresh)
                } catch {
                    storeFailed(error, during: "Recording the last use of", layout: id)
                }
            } else {
                setActiveLayout(nil)
                log.record(
                    .notice, .dock,
                    "Layout \(id) changed while it was being applied; the active mark was cleared"
                )
            }
        } catch {
            raise(.failure(dockFailed(error, during: "Applying layout \(id)")))
        }
    }

    private func quitOthers(for layout: DockLayout) {
        // A layout whose applications are all gone writes an empty Dock, and
        // "everything outside an empty layout" is every app the user has open.
        guard !layout.dockState(skippingMissing: .default).apps.isEmpty else { return }
        let kept = Set(layout.apps.map(\.bundleId))
        let quitting = quitter.runningBundleIds().subtracting(kept)
        quitter.quit(bundleIds: quitting)
        if !quitting.isEmpty {
            log.record(
                .notice, .autoQuit,
                "Asked \(quitting.count) apps to quit: \(quitting.sorted().joined(separator: ", "))"
            )
        }
    }

    public func saveCurrentDock(named name: String) throws {
        let state: DockState
        do {
            state = try switcher.readCurrentState()
        } catch {
            raise(.failure(dockFailed(error, during: "Reading the Dock for a new layout")))
            throw error
        }

        let layout = DockLayout(
            order: (layouts.map(\.order).max() ?? -1) + 1,
            name: name.trimmingCharacters(in: .whitespacesAndNewlines),
            state: state
        ).withUniqueApps()
        do {
            try store.save(layout)
        } catch {
            storeFailed(error, during: "Saving", layout: layout.id)
            raise(.saveFailed)
            throw error
        }
        layouts.append(layout)
        listDidChange()
        page = .layout(layout.id)
    }

    public func seedInitialLayoutIfNeeded() {
        guard layouts.isEmpty, unreadableFiles.isEmpty, !storeUnavailable else { return }
        let state: DockState
        do {
            state = try switcher.readCurrentState()
        } catch {
            dockFailed(error, during: "Capturing the first Dock")
            return
        }

        let layout = DockLayout(order: 0, name: "Dock 1", state: state).withUniqueApps()
        do {
            try store.save(layout)
        } catch {
            storeFailed(error, during: "Seeding", layout: layout.id)
            return
        }

        layouts.append(layout)
        setActiveLayout(layout.id)
        listDidChange()
        log.record(
            .notice, .layouts,
            "First launch captured the current Dock as layout \(layout.id)"
        )
    }

    public func deleteSelected() {
        guard let id = selectedLayout?.id else { return }
        delete(id: id)
    }

    public func delete(id: UUID) {
        do {
            try store.delete(id: id)
        } catch {
            storeFailed(error, during: "Deleting", layout: id)
            raise(.deleteFailed)
            return
        }
        shortcuts.clear(for: id)
        layouts.removeAll { $0.id == id }
        if activeLayoutID == id {
            setActiveLayout(nil)
        }
        listDidChange()
    }

    @discardableResult
    public func rename(id: UUID, to name: String) -> Bool {
        guard var layout = layouts.first(where: { $0.id == id }) else { return false }

        let others = layouts.filter { $0.id != id }.map(\.name)
        guard LayoutNameValidator.problem(for: name, existing: others) == nil else {
            return false
        }

        layout.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            try store.save(layout)
        } catch {
            storeFailed(error, during: "Renaming", layout: id)
            raise(.saveFailed)
            return false
        }
        replace(layout)
        return true
    }

    public func setQuitsOtherApps(id: UUID, _ on: Bool) {
        guard var layout = layouts.first(where: { $0.id == id }),
              layout.quitsOtherApps != on
        else { return }

        layout.quitsOtherApps = on
        do {
            try store.save(layout)
        } catch {
            storeFailed(error, during: "Setting Auto-Quit on", layout: id)
            raise(.saveFailed)
            return
        }
        replace(layout)
    }

    public func moveApp(in id: UUID, from: Int, to: Int) {
        guard from != to else { return }
        moveApps(in: id, fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
    }

    public func moveApps(in id: UUID, fromOffsets source: IndexSet, toOffset destination: Int) {
        mutate(id) { Self.move(&$0.apps, fromOffsets: source, toOffset: destination) }
    }

    /// Not SwiftUI's `move(fromOffsets:toOffset:)`: that lives in a SwiftUI
    /// extension, and the model does not import the UI. Same semantics.
    static func move(
        _ apps: inout [DockApp],
        fromOffsets source: IndexSet,
        toOffset destination: Int
    ) {
        let moved = source.sorted().compactMap { apps.indices.contains($0) ? apps[$0] : nil }
        guard !moved.isEmpty else { return }

        for index in source.sorted(by: >) where apps.indices.contains(index) {
            apps.remove(at: index)
        }
        let shift = source.filter { $0 < destination }.count
        let target = min(max(destination - shift, 0), apps.count)
        apps.insert(contentsOf: moved, at: target)
    }

    public func removeApp(in id: UUID, at index: Int) {
        mutate(id) { layout in
            guard layout.apps.indices.contains(index) else { return }
            layout.apps.remove(at: index)
        }
    }

    @discardableResult
    public func addApp(in id: UUID, atPath path: String, insertingAt index: Int? = nil) -> Bool {
        addApps(in: id, atPaths: [path], insertingAt: index) == 1
    }

    @discardableResult
    public func addApps(
        in id: UUID,
        atPaths paths: [String],
        insertingAt index: Int? = nil
    ) -> Int {
        let apps = paths.compactMap(Self.dockApp(atPath:))
        guard !apps.isEmpty else { return 0 }

        var added = 0
        mutate(id) { layout in
            var at = min(index ?? layout.apps.count, layout.apps.count)
            for app in apps where !layout.apps.contains(where: { $0.id == app.id }) {
                layout.apps.insert(app, at: at)
                at += 1
                added += 1
            }
        }
        return added
    }

    static func dockApp(atPath path: String) -> DockApp? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard url.pathExtension == "app",
              let bundleId = Bundle(url: url)?.bundleIdentifier
        else { return nil }

        let shown = FileManager.default.displayName(atPath: url.path)
        let label = shown.hasSuffix(".app") ? String(shown.dropLast(4)) : shown

        return DockApp(path: url.path, bundleId: bundleId, label: label)
    }

    private func mutate(_ id: UUID, _ change: (inout DockLayout) -> Void) {
        guard var layout = layouts.first(where: { $0.id == id }) else { return }
        let before = layout
        change(&layout)
        guard layout != before else { return }
        do {
            try store.save(layout)
        } catch {
            storeFailed(error, during: "Editing", layout: id)
            raise(.saveFailed)
            return
        }
        replace(layout)
        if id == activeLayoutID {
            setActiveLayout(nil)
        }
    }

    private nonisolated static let lastUsedFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.doesRelativeDateFormatting = true
        return formatter
    }()

    public nonisolated static func lastUsedLabel(_ date: Date?) -> String {
        guard let date else { return "Never used" }
        return "Last used \(lastUsedFormatter.string(from: date))"
    }

    public func askDelete() {
        guard let layout = selectedLayout else { return }
        raise(.delete(id: layout.id, name: layout.name))
    }

    public func beginPresenting() -> ShitsuraeAlertKind? {
        guard !presenting, let kind = alerts.first else { return nil }
        presenting = true
        return kind
    }

    public func dismissAlert(_ kind: ShitsuraeAlertKind) {
        guard alerts.first == kind else { return }
        alerts.removeFirst()
        presenting = false
    }

    public func confirmAlert(_ kind: ShitsuraeAlertKind) async {
        guard alerts.first == kind else { return }
        alerts.removeFirst()
        presenting = false
        switch kind {
        case let .delete(id, _):
            delete(id: id)
        case .failure, .saveFailed, .deleteFailed:
            break
        }
    }

    @discardableResult
    private func dockFailed(_ error: DockError, during operation: String) -> ShitsuraeFailure {
        let reason = ShitsuraeFailure(from: error)
        log.record(.error, .dock, "\(operation) failed: \(reason) — \(error)")
        return reason
    }

    private func storeFailed(_ error: any Error, during operation: String, layout id: UUID) {
        log.record(.error, .layouts, "\(operation) layout \(id) failed: \(error)")
    }

    private func raise(_ kind: ShitsuraeAlertKind) {
        guard !alerts.contains(kind) else { return }
        alerts.append(kind)
    }
}

/// Restarting the Dock waits for the old process to go, so this work blocks its
/// thread outright. The cooperative pool has one thread per core and must not be
/// one of them.
private func offMainThread<T: Sendable>(
    _ work: @escaping @Sendable () throws(DockError) -> T
) async throws(DockError) -> T {
    let result: Result<T, DockError> = await withCheckedContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            continuation.resume(returning: Result(catching: work))
        }
    }
    return try result.get()
}
