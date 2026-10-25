import SwiftUI

/// The two pill styles in Figma: on cards (filled, outlined), and in the bottom
/// bar (larger, liquid glass).
enum PillStyle {
    case card, bar

    var iconSize: CGFloat { self == .card ? D.Size.cardIcon : D.Size.barIcon }
    var padding: CGFloat { self == .card ? D.Size.cardIconPadding : D.Size.barIconPadding }
    var diameter: CGFloat { iconSize + padding * 2 }
    var fill: Color { self == .card ? D.pillFill : D.barButtonFill }
}

/// The round icon shared by every pill control: the glyph centred in a fixed square,
/// so the surface around it is always a true circle.
struct PillIcon: View {
    let icon: String
    var style: PillStyle = .card

    var body: some View {
        Image(icon)
            .resizable()
            .scaledToFit()
            .frame(width: style.iconSize, height: style.iconSize)
            .frame(width: style.diameter, height: style.diameter)
            .contentShape(Circle())
    }
}

/// Card pills are flat fills: a list holds many cards, and glass on each would sample
/// the backdrop dozens of times while scrolling. Bar pills are liquid glass, a handful
/// at most, grouped in one `GlassEffectContainer` by the bar.
///
/// Applied outside the control, not inside its label: AppKit draws a `Menu` label as a
/// flat image, which clips and distorts glass drawn inside it.
private struct PillSurface: ViewModifier {
    let style: PillStyle

    func body(content: Content) -> some View {
        switch style {
        case .card:
            content
                .background(Circle().fill(style.fill))
                .overlay { Circle().strokeBorder(D.pillStroke, lineWidth: 1) }
        case .bar:
            content.dannyGlass(tint: style.fill, in: Circle(), interactive: true)
        }
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
        .modifier(PillSurface(style: style))
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
        .frame(width: style.diameter, height: style.diameter)
        .modifier(PillSurface(style: style))
    }
}
