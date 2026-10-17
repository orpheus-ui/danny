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

            Section("Organizing") {
                Toggle("Save into a folder per site", isOn: $settings.folderPerSite)
                Picker("File name", selection: $settings.filenameTemplate) {
                    ForEach(FilenameTemplate.allCases) { Text($0.label).tag($0) }
                }
                LabeledContent("Example") {
                    Text(settings.filenameTemplate.preview(siteFolder: settings.folderPerSite))
                        .font(.system(size: 11, design: .monospaced))
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                Text("Danny ends every name with the video's id, which is how it recognizes a file it already has.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Network") {
                Toggle("Download only on Wi-Fi", isOn: $settings.downloadsOnlyOnWiFi)
                Text("""
                On an iPhone hotspot or another metered connection, new downloads wait and start \
                once the Mac is back on Wi-Fi or Ethernet. Downloads already running carry on.
                """)
                .font(.caption)
                .foregroundStyle(.secondary)
                Picker("Speed limit", selection: $settings.speedLimit) {
                    ForEach(AppSettings.speedLimits, id: \.self) { limit in
                        Text(Format.speed(Double(limit)).map { "\($0) per download" } ?? "None").tag(limit)
                    }
                }
            }

            AccountsSection()

            Section("Clipboard") {
                Picker("Copied links", selection: $settings.clipboard) {
                    ForEach(ClipboardPolicy.allCases) { Text($0.label).tag($0) }
                }
                Text("Danny looks for a copied video link when you switch to it.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Toggle("Show progress and Paste to Download in the menu bar", isOn: $settings.menuBarItem)
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
