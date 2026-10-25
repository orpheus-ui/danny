import SwiftUI

struct EngineSettings: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadManager.self) private var manager
    @State private var engineStatus = "Checking…"

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                LabeledContent("Download engine") {
                    HStack {
                        Text(engineStatus)
                        if manager.isCheckingEngine { ProgressView().controlSize(.small) }
                        Button("Check Now") { Task { await manager.checkEngine(manual: true) } }
                            .disabled(manager.isCheckingEngine)
                    }
                }
                if let lastCheck { SettingsNote(lastCheck) }
                Toggle("Keep yt-dlp up to date", isOn: $settings.keepsEngineCurrent)
                SettingsNote(engineNote)
            }
        }
        .formStyle(.grouped)
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
}
