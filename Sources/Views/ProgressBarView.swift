import SwiftUI

/// The progress bar from Figma: a glassy track, a fill with halftone dots drawn by a
/// Metal shader (`ProgressBar.metal`), and a light that passes through the dots
/// (`ProgressLight`).
///
/// Light work (ADR-008): the fill is static and only redrawn when progress changes;
/// the light is moved by Core Animation outside the app, and stops while the window
/// is hidden or Reduce Motion is on.
struct ProgressBarView: View {
    let item: DownloadItem
    var onRetry: (() -> Void)?
    var onBrowserCapture: (() -> Void)?
    /// Shown instead of Browser Capture when the site wants a signed-in user.
    var onSignIn: (() -> Void)?
    /// A finished card's actions while it is hovered, as chips at the bar's trailing end.
    var finishedActions: [Chip] = []
    /// Shown on a running bar; the card passes it only while hovered.
    var onPause: (() -> Void)?
    var onResume: (() -> Void)?

    struct Chip {
        let icon: String
        let title: String
        let action: () -> Void
    }

    @Environment(\.windowIsVisible) private var windowIsVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(DownloadManager.self) private var manager: DownloadManager?

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                track
                if let style = fillStyle {
                    fill(style, width: fillWidth(in: geo.size.width), track: geo.size.width)
                }
            }
        }
        .frame(height: D.Size.progressHeight)
        .overlay { label }
        .overlay(alignment: .trailing) {
            if item.status == .failed { failedActions }
            if item.status == .finished, !finishedActions.isEmpty { doneActions }
            if item.status.canPause, let onPause { chip(icon: "pause.fill", title: "Pause", action: onPause) }
            if item.status == .paused, let onResume { chip(icon: "play.fill", title: "Resume", action: onResume) }
        }
    }

    // MARK: Track and fill

    private var track: some View {
        Capsule()
            .fill(D.progressTrack)
            .overlay {
                Capsule()
                    .stroke(D.progressInnerShadow, lineWidth: 2)
                    .blur(radius: 1)
                    .offset(y: 1)
                    .clipShape(Capsule())
            }
            .shadow(color: D.progressRim, radius: 0, y: 1)
    }

    private func fill(_ style: FillStyle, width: CGFloat, track: CGFloat) -> some View {
        DottedFill(width: width, style: style)
            .opacity(item.status == .paused ? 0.45 : 1)
            .overlay(alignment: .leading) {
                ProgressLight(trackWidth: track, isRunning: sweeps)
            }
            .clipShape(Capsule())
            .animation(.easeOut(duration: 0.45), value: width)
    }

    /// The fill and its shader take the same animated width: a `Shader.Argument` isn't
    /// interpolated, so passing the target width while the frame animates would lay the
    /// dots out for the wrong size until the animation ends.
    private struct DottedFill: View, Animatable {
        var width: CGFloat
        let style: FillStyle

        var animatableData: CGFloat {
            get { width }
            set { width = newValue }
        }

        var body: some View {
            Capsule()
                .fill(style.gradient)
                .colorEffect(ShaderLibrary.progressFill(
                    .float2(width, D.Size.progressHeight),
                    .color(style.dotStart), .color(style.dotEnd),
                ))
                .frame(width: width)
        }
    }

    private func fillWidth(in total: CGFloat) -> CGFloat {
        guard item.status == .downloading || item.status == .paused else { return total }
        // A card paused before its first byte has nothing to fill.
        guard let fraction = item.fractionCompleted else { return item.status == .paused ? 0 : total }
        let clamped = CGFloat(min(max(fraction, 0), 1))
        return clamped > 0 ? max(total * clamped, D.Size.progressHeight) : 0
    }

    private struct FillStyle {
        let gradient: LinearGradient
        let dotStart: Color
        let dotEnd: Color
    }

    private var fillStyle: FillStyle? {
        switch item.status {
        case .queued, .choosing, .existing:
            nil
        case .resolving, .downloading, .processing, .paused:
            FillStyle(gradient: D.progressFill, dotStart: D.progressDotStart, dotEnd: D.progressDotEnd)
        case .finished:
            FillStyle(gradient: D.doneFill, dotStart: D.doneStart, dotEnd: D.doneEnd)
        case .failed:
            FillStyle(gradient: D.failedFill, dotStart: D.failedStart, dotEnd: D.failedEnd)
        }
    }

    // MARK: The passing light

    /// Whether the light passes at all now.
    private var sweeps: Bool {
        let working = item.status == .downloading || item.status == .resolving || item.status == .processing
        return working && windowIsVisible && !reduceMotion
    }

    // MARK: Label

    private var label: some View {
        HStack(spacing: 10) {
            ForEach(Array(labelParts.enumerated()), id: \.offset) { _, part in
                Text(part)
            }
        }
        .font(D.Font.progressLabel)
        .foregroundStyle(D.progressLabel)
        .shadow(color: .black.opacity(0.3), radius: 1, y: 0.5)
        .lineLimit(1)
        .fixedSize()
        .contentTransition(.numericText())
    }

    private var labelParts: [String] {
        switch item.status {
        case .queued: manager?.waitsForWiFi == true ? ["Waiting for Wi-Fi"] : []
        case .choosing, .existing: []
        case .resolving: ["Fetching…"]
        case .downloading: downloadingParts
        case .processing: ["Merging…"]
        case .paused: Format.percent(item.fractionCompleted).map { ["Paused", "·", $0] } ?? ["Paused"]
        case .finished: ["Done"]
        case .failed: [item.failureReason?.text ?? "Failed"]
        }
    }

    private var downloadingParts: [String] {
        let speed = Format.speed(item.speedBytesPerSecond)
        guard let percent = Format.percent(item.fractionCompleted) else { return [speed ?? "Starting…"] }
        return speed.map { [percent, "-", $0] } ?? [percent]
    }

    // MARK: Failed

    private var failedActions: some View {
        HStack(spacing: 6) {
            switch item.failureReason?.action {
            case .signIn:
                if let onSignIn {
                    miniButton(icon: "person.crop.circle", title: "Sign In", action: onSignIn)
                } else if let onBrowserCapture {
                    miniButton(icon: "globe", title: "Browser Capture", action: onBrowserCapture)
                }
            case .browserCapture:
                if let onBrowserCapture {
                    miniButton(icon: "globe", title: "Browser Capture", action: onBrowserCapture)
                }
            case .retry:
                if let onRetry {
                    miniButton(icon: "arrow.clockwise", title: "Retry", action: onRetry)
                }
            case .nothing, nil:
                EmptyView()
            }
        }
        .padding(.trailing, 6)
    }

    /// Pause and Resume: one labelled chip, like Retry on a failed bar.
    private func chip(icon: String, title: String, action: @escaping () -> Void) -> some View {
        miniButton(icon: icon, title: title, action: action)
            .padding(.trailing, 6)
            .transition(.opacity)
    }

    // MARK: Done

    /// Icon-only: four labelled chips don't fit beside "Done" at the window's minimum width.
    private var doneActions: some View {
        HStack(spacing: 6) {
            ForEach(finishedActions, id: \.title) { chip in
                miniButton(icon: chip.icon, title: nil, action: chip.action)
                    .help(chip.title)
                    .accessibilityLabel(chip.title)
            }
        }
        .padding(.trailing, 6)
        .transition(.opacity)
    }

    private func miniButton(icon: String, title: String?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                if let title {
                    Text(title).font(.system(size: 10, weight: .bold))
                }
            }
            .foregroundStyle(.white.opacity(0.95))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Capsule().fill(Color.black.opacity(0.35)))
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
