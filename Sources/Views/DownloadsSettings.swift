import AppKit
import SwiftUI

struct DownloadsSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
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
                SettingsNote(
                    "Danny ends every name with the video's id, which is how it recognizes a file it already has.",
                )
            }
        }
        .formStyle(.grouped)
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
