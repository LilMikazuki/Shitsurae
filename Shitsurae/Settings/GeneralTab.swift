import ShitsuraeKit
import SwiftUI

struct GeneralTab: View {
    let launchAtLogin: any LaunchAtLoginControlling

    @State private var launchEnabled = false

    @State private var launchProblem: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("General")
                .font(.system(size: 18, weight: .semibold))
                .padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 14) {
                Toggle(isOn: launchBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Launch at login")
                        Text("Shitsurae keeps running in the menu bar after you close this window.")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }

                if let launchProblem {
                    Text(launchProblem)
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Divider().padding(.vertical, 20)

            HStack(alignment: .top, spacing: 16) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Shitsurae").font(.system(size: 18, weight: .semibold))
                    Text("Version \(shortVersion) (\(build)) · MIT License")
                        .font(.system(size: 13.5))
                        .foregroundStyle(.secondary)
                    Link(
                        "github.com/LilMikazuki/shitsurae",
                        destination: URL(string: "https://github.com/LilMikazuki/shitsurae")!
                    )
                    .font(.system(size: 13.5))
                }
                .padding(.top, 4)
            }

            Spacer()

            Text("Dock layouts are stored in ~/Library/Application Support/Shitsurae.")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)
        }
        .padding(EdgeInsets(top: 22, leading: 26, bottom: 22, trailing: 26))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            launchEnabled = launchAtLogin.isEnabled
            launchProblem = nil
        }
    }

    private var launchBinding: Binding<Bool> {
        Binding(get: { launchEnabled }, set: { setLaunchAtLogin($0) })
    }

    private func setLaunchAtLogin(_ on: Bool) {
        do {
            try launchAtLogin.setEnabled(on)
        } catch {}
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
