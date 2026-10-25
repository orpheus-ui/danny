import SwiftUI

struct GeneralSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section("Clipboard") {
                Picker("Copied links", selection: $settings.clipboard) {
                    ForEach(ClipboardPolicy.allCases) { Text($0.label).tag($0) }
                }
                SettingsNote("Danny looks for a copied video link when you switch to it.")
            }
            Section("Menu bar") {
                Toggle("Show progress and Paste to Download in the menu bar", isOn: $settings.menuBarItem)
            }
        }
        .formStyle(.grouped)
    }
}
