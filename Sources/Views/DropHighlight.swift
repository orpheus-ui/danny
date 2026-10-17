import SwiftUI

/// Shown over the list while a link is dragged over the window: one glass panel
/// with an accent stroke, saying the drop adds a download.
struct DropHighlight: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: D.Radius.card, style: .continuous)
        VStack(spacing: 8) {
            Image("icon-plus")
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(0.8)
            Text("Drop to download")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(D.textPrimary.opacity(0.85))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .dannyGlass(tint: D.accent.opacity(0.12), in: shape)
        .overlay(shape.strokeBorder(D.accent.opacity(0.8), lineWidth: D.Stroke.card))
        .accessibilityElement(children: .combine)
    }
}
