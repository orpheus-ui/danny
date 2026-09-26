import AppKit
import SwiftUI

struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadManager.self) private var manager
    @State private var engineStatus = "Checking…"

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section("Engine") {
                LabeledContent("Download engine", value: engineStatus)
                Text("""
                YouTube and other sites change constantly. If downloads fail with HTTP 403, \
                update yt-dlp: `brew upgrade yt-dlp`.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Section("Downloads") {
                HStack {
                    Text("Save to")
                    Spacer()
                    Text(settings.downloadDirectory.path)
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                    Button("Choose…") { chooseFolder() }
                }
                Stepper(
                    "Simultaneous downloads: \(settings.maxConcurrentDownloads)",
                    value: $settings.maxConcurrentDownloads,
                    in: 1 ... 6,
                )
            }

            Section("Clipboard") {
                Toggle("Watch clipboard for links", isOn: $settings.monitorClipboard)
                Text("When enabled, copied video links are added to the queue automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Browser capture") {
                Toggle("Consent granted", isOn: $settings.browserConsentGiven)
                Text("""
                The capture browser watches network traffic in its own window so you can pick \
                streams Danny couldn't extract on its own.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Settings")
        .task {
            engineStatus = await manager.toolVersions()
        }
    }

    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = settings.downloadDirectory
        if panel.runModal() == .OK, let url = panel.url {
            settings.downloadDirectory = url
        }
    }
}
