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
                Toggle("Block ads and trackers", isOn: $settings.blocksAds)
                SettingsNote("""
                Pages load faster and ads stay out of Captured Media. If a page breaks, \
                allow it with the shield in the capture browser's toolbar. Sign-in pages \
                are never blocked.
                """)
            }
        }
        .formStyle(.grouped)
    }
}
