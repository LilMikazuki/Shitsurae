import ShitsuraeKit
import SwiftUI

struct LayoutSidebar: View {
    @Bindable var model: AppModel
    @Binding var showingGeneral: Bool
    @Environment(\.openWindow) private var openWindow

    @State private var editingID: UUID?
    @State private var editValue = ""
    @FocusState private var editFocused: Bool
    @State private var renameProblem: String?

    var body: some View {
        VStack(spacing: 0) {
            list

            if !model.unreadableFiles.isEmpty {
                Text("\(model.unreadableFiles.count) layout file(s) could not be read")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.orange)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 17)
                    .padding(.bottom, 6)
                    .help(model.unreadableFiles.joined(separator: "\n"))
            }

            Rectangle()
                .fill(.separator)
                .frame(height: 0.5)
            footer
        }
        .onChange(of: model.selectedLayoutID) { _, _ in
            showingGeneral = false
            if let editingID, editingID != model.selectedLayoutID {
                commitRename()
            }
        }
    }

    @ViewBuilder
    private var list: some View {
        if model.layouts.isEmpty {
            Text(
                model.storeUnavailable
                    ? "Can’t read your saved layouts. They are still on disk — check "
                    + "~/Library/Application Support/Shitsurae."
                    : "No layouts yet — save your current Dock to start"
            )
            .font(.system(size: 13.5))
            .foregroundStyle(model
                .storeUnavailable ? AnyShapeStyle(.red) : AnyShapeStyle(.tertiary))
            .multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
            .padding(EdgeInsets(top: 14, leading: 17, bottom: 14, trailing: 17))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            List(selection: $model.selectedLayoutID) {
                ForEach(model.layouts) { layout in
                    row(layout)
                        .tag(layout.id)
                }
            }
            .listStyle(.sidebar)
            .onKeyPress(.return) {
                guard editingID == nil, let layout = model.selectedLayout else { return .ignored }
                startRename(layout)
                return .handled
            }
        }
    }

    private func row(_ layout: DockLayout) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                if editingID == layout.id {
                    TextField("", text: $editValue)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .focused($editFocused)
                        .onSubmit(commitRename)
                        .onExitCommand {
                            editingID = nil
                            renameProblem = nil
                        }
                } else {
                    Text(layout.name)
                        .font(.system(size: 15))
                        .lineLimit(1)
                        .truncationMode(.tail)
                }

                if layout.id == model.activeLayoutID {
                    Text("Active")
                        .font(.system(size: 10, weight: .semibold))
                        .textCase(.uppercase)
                        .tracking(0.5)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1.5)
                        .background(.quaternary, in: .rect(cornerRadius: 4))
                        .foregroundStyle(.secondary)
                }
            }

            if editingID == layout.id, let renameProblem {
                Text(renameProblem)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Text(LayoutSummary.appCount(layout))
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 5)
        .contextMenu {
            let isApplied = layout.id == model.activeLayoutID

            Button("Apply") {
                Task {
                    await model.apply(id: layout.id)
                }
            }
            .disabled(isApplied || model.isChangingDock)

            Button("Rename…") {
                model.selectedLayoutID = layout.id
                startRename(layout)
            }

            Divider()

            Button("Delete…", role: .destructive) {
                model.selectedLayoutID = layout.id
                model.askDelete()
            }
        }
    }

    private var footer: some View {
        HStack {
            Button {
                NSApplication.shared.activate()
                openWindow(id: "save-layout")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "plus")
                        .font(.system(size: 13.5))
                        .frame(width: 14)
                    Text("New Layout")
                        .font(.system(size: 13.5))
                }
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)

            Spacer()

            Button {
                showingGeneral.toggle()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(
                        showingGeneral
                            ? AnyShapeStyle(Color.primary.opacity(0.07))
                            : AnyShapeStyle(.clear),
                        in: .rect(cornerRadius: 6)
                    )
            }
            .buttonStyle(.plain)
            .pointerStyle(.link)
            .help("General settings")
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(height: 34)
    }

    private func startRename(_ layout: DockLayout) {
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
