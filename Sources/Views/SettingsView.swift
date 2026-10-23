import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            Tab("General", systemImage: "gearshape") { GeneralSettings() }
            Tab("Downloads", systemImage: "arrow.down.circle") { DownloadsSettings() }
            Tab("Quality", systemImage: "film") { QualitySettings() }
            Tab("Network", systemImage: "network") { NetworkSettings() }
            Tab("Sources", systemImage: "person.crop.circle") { SourcesSettings() }
            Tab("Engine & Updates", systemImage: "arrow.triangle.2.circlepath") { EngineSettings() }
        }
    }
}
