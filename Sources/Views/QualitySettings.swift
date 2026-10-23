import SwiftUI

struct QualitySettings: View {
    @Environment(AppSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings
        return Form {
            Section {
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
                SettingsNote(formatNote)
            }
        }
        .formStyle(.grouped)
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
}
