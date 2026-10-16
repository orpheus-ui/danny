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
                Picker("Quality", selection: $settings.quality) {
                    ForEach(QualityPreference.allCases) { preference in
                        if preference == .audioOnly || preference == .ask { Divider() }
                        Text(preference.label).tag(preference)
                    }
                }
                Picker("Format", selection: $settings.format) {
                    ForEach(FormatPreference.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.radioGroup)
                Text(formatNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Stepper(
                    "Simultaneous downloads: \(settings.maxConcurrentDownloads)",
                    value: $settings.maxConcurrentDownloads,
                    in: 1 ... 6,
                )
            }

            AccountsSection()

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

    private var formatNote: String {
        switch settings.format {
        case .compatible:
            "Prefers MP4 with H.264 or HEVC: plays in QuickTime, Photos, on iPhone and in editors. "
                + "When a site has neither, Danny takes another codec rather than failing."
        case .highest:
            "The best the site has, in any codec. 4K and up are often VP9 or AV1, saved as MKV "
                + "when MP4 can't hold them; QuickTime may not play those."
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
