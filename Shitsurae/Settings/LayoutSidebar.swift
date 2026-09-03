import ShitsuraeKit
import SwiftUI

struct LayoutSidebar: View {
    let model: AppModel
    @Environment(\.openWindow) private var openWindow

    @State private var editingID: UUID?
    @State private var editValue = ""
    @FocusState private var editFocused: Bool
    @State private var renameProblem: String?

    var body: some View {
        list
            .safeAreaBar(edge: .bottom) { footer }
            .onChange(of: model.page) { _, new in
                if let editingID, new != .layout(editingID) {
                    commitRename()
                }
            }
    }

    private var selection: Binding<SettingsPage?> {
        Binding(
            get: { model.page },
            set: { new in
                guard let new else { return }
                model.page = new
            }
        )
    }

    private var list: some View {
        List(selection: selection) {
            if model.layouts.isEmpty {
                emptyNote
            } else {
                Section {
                    ForEach(model.layouts) { layout in
                        row(layout)
                            .tag(SettingsPage.layout(layout.id))
                    }
                }
            }

            if let note = SidebarNote.unreadable(model.unreadableFiles) {
                folderNote(note, files: model.unreadableFiles)
            }

            if let note = SidebarNote.duplicates(model.duplicateFiles) {
                folderNote(note, files: model.duplicateFiles.map(\.name))
            }

            Section {
                Label("General", systemImage: "gearshape")
                    .tag(SettingsPage.general)
            }
        }
        .listStyle(.sidebar)
        .contextMenu(forSelectionType: SettingsPage.self) { pages in
            layoutMenu(for: pages.first)
        }
        .onKeyPress(.return) {
            guard editingID == nil, let layout = model.selectedLayout else { return .ignored }
            startRename(layout)
            return .handled
        }
    }

    @ViewBuilder
    private func layoutMenu(for selected: SettingsPage?) -> some View {
        if case let .layout(id) = selected,
           let layout = model.layouts.first(where: { $0.id == id })
        {
            Button("Apply") {
                Task {
                    await model.apply(id: id)
                }
            }
            .disabled(id == model.activeLayoutID || model.isChangingDock)

            Button("Rename") {
                startRename(layout)
            }

            Divider()

            Button("Delete", role: .destructive) {
                model.page = .layout(id)
                model.askDelete()
            }
        }
    }

    private func row(_ layout: DockLayout) -> some View {
        Label {
            if editingID == layout.id {
                VStack(alignment: .leading, spacing: 2) {
                    TextField("", text: $editValue)
                        .textFieldStyle(.plain)
                        .focused($editFocused)
                        .onSubmit(commitRename)
                        .onExitCommand {
                            editingID = nil
                            renameProblem = nil
                        }

                    if let renameProblem {
                        Text(renameProblem)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } else {
                Text(layout.name)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        } icon: {
            Image(systemName: "rectangle.bottomthird.inset.filled")
        }
        .badge(layout.id == model.activeLayoutID ? Text("Active") : nil)
    }

    private func folderNote(_ text: String, files: [String]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(text)
                .font(.callout)
                .foregroundStyle(.orange)
                .lineLimit(nil)

            Button(SidebarNote.revealTitle) {
                NSWorkspace.shared.activateFileViewerSelecting(
                    files.map { model.layoutsFolder.appendingPathComponent($0) }
                )
            }
            .buttonStyle(.link)
            .font(.callout)
            .pointerStyle(.link)
            .help(files.joined(separator: "\n"))
        }
        .padding(.vertical, 4)
    }

    private var emptyNote: some View {
        Text(
            model.storeUnavailable
                ? "Can’t read your saved layouts. They are still on disk — check "
                + "~/Library/Application Support/Shitsurae."
                : "No layouts yet — save your current Dock to start"
        )
        .font(.callout)
        .foregroundStyle(model.storeUnavailable ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
        .lineLimit(nil)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.vertical, 6)
    }

    private var footer: some View {
        HStack {
            Button {
                NSApplication.shared.activate()
                openWindow(id: "save-layout")
            } label: {
                Label("New Layout", systemImage: "plus")
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)

            Spacer()
        }
        .padding(.leading, 17)
        .padding(.trailing, 12)
        .frame(height: 34)
        .padding(.bottom, 8)
    }

    private func startRename(_ layout: DockLayout) {
        model.page = .layout(layout.id)
        editValue = layout.name
        editingID = layout.id
        renameProblem = nil
        editFocused = true
    }

    private func commitRename() {
        guard let id = editingID else { return }
        guard model.layouts.contains(where: { $0.id == id }) else {
            editingID = nil
            renameProblem = nil
            return
        }
        if model.rename(id: id, to: editValue) {
            editingID = nil
            renameProblem = nil
        } else {
            renameProblem = LayoutNameValidator
                .problem(
                    for: editValue,
                    existing: model.layouts.filter { $0.id != id }.map(\.name)
                )?
                .message
            editFocused = true
        }
    }
}
