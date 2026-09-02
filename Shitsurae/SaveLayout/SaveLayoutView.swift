import ShitsuraeKit
import SwiftUI

struct SaveLayoutView: View {
    let model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @FocusState private var nameFocused: Bool

    private var problem: LayoutNameProblem? {
        LayoutNameValidator.problem(for: name, existing: model.layouts.map(\.name))
    }

    private var canSave: Bool {
        problem == nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Save Current Dock as Layout")
                .font(.system(size: 15.5, weight: .semibold))
                .padding(.bottom, 14)

            HStack(spacing: 9) {
                Text("Name")
                    .frame(width: 44, alignment: .trailing)
                TextField("", text: $name)
                    .textFieldStyle(.roundedBorder)
                    .focused($nameFocused)
                    .onSubmit(save)
                    .overlay {
                        if problem != nil {
                            RoundedRectangle(cornerRadius: 6)
                                .strokeBorder(.red, lineWidth: 1)
                        }
                    }
            }
            .padding(.bottom, 5)

            if let message = problem?.message {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.red)
                    Text(message)
                        .foregroundStyle(.red)
                }
                .font(.system(size: 13))
                .padding(.leading, 53)
                .padding(.bottom, 5)
            }

            HStack(spacing: 9) {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                    .frame(minWidth: 66)
                Button("Save", action: save)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canSave)
                    .frame(minWidth: 66)
            }
            .padding(.top, 13)
        }
        .padding(EdgeInsets(top: 18, leading: 20, bottom: 16, trailing: 20))
        .frame(width: 415)
        .onAppear {
            name = LayoutNameValidator.defaultName(existingCount: model.layouts.count)
            nameFocused = true
        }
    }

    private func save() {
        guard canSave else { return }
        guard (try? model.saveCurrentDock(named: name)) != nil else { return }
        dismiss()
    }
}
