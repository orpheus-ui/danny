import SwiftUI

struct PillButton: View {
    let icon: String
    var iconSize: CGFloat = 18
    var padding: CGFloat = 6
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .padding(padding)
                .dannyGlass(tint: Color.black.opacity(0.30), in: .capsule, interactive: true)
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
            Image(icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: iconSize, height: iconSize)
                .padding(padding)
                .dannyGlass(tint: Color.black.opacity(0.30), in: .capsule, interactive: true)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
