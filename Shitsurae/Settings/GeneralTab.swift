import ShitsuraeKit
import SwiftUI

struct GeneralTab: View {
    let launchAtLogin: any LaunchAtLoginControlling
    private let log: any EventLog = SystemEventLog()

    @State private var launchEnabled = false
    @State private var launchProblem: String?

    var body: some View {
        form
            .onAppear {
                launchEnabled = launchAtLogin.isEnabled
                launchProblem = nil
            }
    }

    private var form: some View {
        Form {
            Section {
                LabeledContent {
                    Toggle("Launch at login", isOn: launchBinding)
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                } label: {
                    Text("Launch at login")
                    Text("Shitsurae keeps running in the menu bar after you close this window.")
                }

                if let launchProblem {
                    Text(launchProblem)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                LabeledContent("Dock layouts folder", value: "~/Library/Application Support")
            }

            Section {
                about
            }
        }
        .formStyle(.grouped)
        .contentMargins(.top, 0, for: .scrollContent)
        // The grouped form keeps about 14pt above its first section that contentMargins does not
        // remove; 46 lands the first card level with the first sidebar row, as 60 does for the
        // Dock strip on the layout page.
        .padding(.top, 46)
    }

    private var about: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 56, height: 56)

            VStack(alignment: .leading, spacing: 3) {
                Text("Shitsurae")
                    .font(.headline)
                Text("Version \(shortVersion) (\(build)) · MIT License")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var launchBinding: Binding<Bool> {
        Binding(get: { launchEnabled }, set: { setLaunchAtLogin($0) })
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try launchAtLogin.setEnabled(on)
        } catch {
            log.record(.error, .launchAtLogin, "Changing the login item failed: \(error)")
        }
        launchEnabled = launchAtLogin.isEnabled
        launchProblem = launchEnabled == on ? nil : (on
            ? "macOS did not allow adding Shitsurae to your login items."
            : "macOS did not allow removing Shitsurae from your login items.")
    }

    private var shortVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    }

    private var build: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    }
}
