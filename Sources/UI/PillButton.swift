import SwiftUI

/// The round glass icon shared by every pill control.
struct PillIcon: View {
    let icon: String
    var iconSize: CGFloat = 18
    var padding: CGFloat = 6

    var body: some View {
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: iconSize, height: iconSize)
            .padding(padding)
            .dannyGlass(tint: Color.black.opacity(0.30), in: .capsule, interactive: true)
    }
}

struct PillButton: View {
    let icon: String
    var iconSize: CGFloat = 18
    var padding: CGFloat = 6
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillIcon(icon: icon, iconSize: iconSize, padding: padding)
        }
        .buttonStyle(.plain)
    }
}

struct PillMenu<Items: View>: View {
    let icon: String
    var iconSize: CGFloat = 18
    var padding: CGFloat = 6
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            PillIcon(icon: icon, iconSize: iconSize, padding: padding)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
