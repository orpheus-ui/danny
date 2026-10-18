import SwiftUI

struct SourcesSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            AccountsSection()

            Section("Browser capture") {
                Toggle("Consent granted", isOn: $settings.browserConsentGiven)
                SettingsNote("""
                The capture browser watches network traffic in its own window so you can pick \
                streams Danny couldn't extract on its own.
                """)
            }
        }
        .formStyle(.grouped)
    }
}
