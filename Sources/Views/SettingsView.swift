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
                LabeledContent("Download engine") {
                    HStack {
                        Text(engineStatus)
                        if manager.isCheckingEngine { ProgressView().controlSize(.small) }
                        Button("Check Now") { Task { await manager.checkEngine(manual: true) } }
                            .disabled(manager.isCheckingEngine)
                    }
                }
                if let lastCheck {
                    Text(lastCheck)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Toggle("Keep yt-dlp up to date", isOn: $settings.keepsEngineCurrent)
                Text(engineNote)
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
                Picker("If the file exists", selection: $settings.existingFiles) {
                    ForEach(ExistingFilePolicy.allCases) { Text($0.label).tag($0) }
                }
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
        .task(id: manager.engineCheck) {
            engineStatus = await manager.toolVersions()
        }
    }

    /// What the last check found. A clock time rather than "2 min ago", which would
    /// need a timer to stay true while Settings is open.
    private var lastCheck: String? {
        guard let check = manager.engineCheck else { return nil }
        let time = check.date.formatted(date: .omitted, time: .shortened)
        return switch check.outcome {
        case let .current(version): "\(version) is the latest · checked at \(time)"
        case let .updated(version): "Updated to \(version) at \(time); used from the next download"
        case let .failed(reason): "The check at \(time) didn't finish: \(reason)"
        }
    }

    private var engineNote: String {
        settings.keepsEngineCurrent
            ? "Sites change often and yt-dlp follows them. Danny fetches its latest release each time it opens, "
            + "and installs it only when it matches yt-dlp's published checksum."
            : "Danny keeps the yt-dlp it has now. Check Now fetches a newer one when you ask."
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
