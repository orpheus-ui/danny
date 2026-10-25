import SwiftUI

struct NetworkSettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
                Toggle("Download only on Wi-Fi", isOn: $settings.downloadsOnlyOnWiFi)
                SettingsNote("""
                On an iPhone hotspot or another metered connection, new downloads wait and start \
                once the Mac is back on Wi-Fi or Ethernet. Downloads already running carry on.
                """)
                Picker("Speed", selection: $settings.speedMode) {
                    ForEach(SpeedMode.allCases) { Text(settings.title(for: $0)).tag($0) }
                }
                SpeedLimitField(title: "Balanced limit", bytesPerSecond: $settings.balancedLimit)
                SpeedLimitField(title: "Background limit", bytesPerSecond: $settings.backgroundLimit)
                SettingsNote("""
                Each download stays under the limit of the mode in use. A change reaches downloads \
                that start after it; the ones already running keep their speed.
                """)
            }
        }
        .formStyle(.grouped)
    }
}
