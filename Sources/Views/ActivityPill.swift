import SwiftUI

/// The bottom bar's summary of the queue, beside Sort: how many cards run and how fast,
/// with Pause All and Resume All in its menu; or, with everything paused, how many and
/// a Resume button. Its text changes with the items only, never on a timer.
struct ActivityPill: View {
    let activity: QueueActivity
    /// Resume All joins the menu while some cards run and others are paused.
    var canResumeAll = false
    let onPauseAll: () -> Void
    let onResumeAll: () -> Void

    var body: some View {
        switch activity {
        case let .active(count, speed):
            Menu {
                Button("Pause All", action: onPauseAll)
                if canResumeAll {
                    Button("Resume All", action: onResumeAll)
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.down").font(.system(size: 11, weight: .bold))
                    Text("\(count)")
                    if let speed = Format.speed(speed) {
                        Text("·").foregroundStyle(D.textSecondary)
                        Text(speed)
                    }
                }
                .modifier(PillText())
            }
            .menuStyle(.button)
            .menuIndicator(.hidden)
            .buttonStyle(.plain)
            .fixedSize()
            .dannyGlass(tint: D.barButtonFill, in: Capsule(), interactive: true)
            .help("Pause or resume all downloads (⌥⌘P)")
            .accessibilityLabel(
                ["\(count) downloading", Format.spokenSpeed(speed)].compactMap(\.self).joined(separator: ", "),
            )
        case let .paused(count):
            HStack(spacing: 8) {
                Text("Paused · \(count)")
                Button(action: onResumeAll) {
                    Text("Resume")
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(Color.black.opacity(0.35)))
                        .contentShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Resume All (⌥⌘P)")
                .accessibilityLabel("Resume All")
            }
            .modifier(PillText(trailing: 7))
            .dannyGlass(tint: D.barButtonFill, in: Capsule())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("\(count) paused")
        }
    }

    /// The label inside the pill: bold white, as tall as the round bar buttons.
    private struct PillText: ViewModifier {
        var trailing: CGFloat = 14

        func body(content: Content) -> some View {
            content
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(D.textPrimary)
                .lineLimit(1)
                .padding(.leading, 14)
                .padding(.trailing, trailing)
                .frame(height: PillStyle.bar.diameter)
                .contentShape(Capsule())
        }
    }
}
