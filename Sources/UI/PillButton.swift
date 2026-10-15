import SwiftUI

/// The two pill styles in Figma: on cards (filled, outlined), and in the bottom
/// bar (larger, lighter, no outline).
enum PillStyle {
    case card, bar

    var iconSize: CGFloat { self == .card ? D.Size.cardIcon : D.Size.barIcon }
    var padding: CGFloat { self == .card ? D.Size.cardIconPadding : D.Size.barIconPadding }
    var fill: Color { self == .card ? D.pillFill : D.barButtonFill }
    var stroke: Color? { self == .card ? D.pillStroke : nil }
}

/// The round icon shared by every pill control.
struct PillIcon: View {
    let icon: String
    var style: PillStyle = .card

    var body: some View {
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: style.iconSize, height: style.iconSize)
            .padding(style.padding)
            .background(Capsule().fill(style.fill))
            .overlay {
                if let stroke = style.stroke { Capsule().strokeBorder(stroke, lineWidth: 1) }
            }
            .contentShape(Capsule())
    }
}

struct PillButton: View {
    let icon: String
    var style: PillStyle = .card
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            PillIcon(icon: icon, style: style)
        }
        .buttonStyle(.plain)
    }
}

struct PillMenu<Items: View>: View {
    let icon: String
    var style: PillStyle = .card
    @ViewBuilder let items: () -> Items

    var body: some View {
        Menu {
            items()
        } label: {
            PillIcon(icon: icon, style: style)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
    }
}
