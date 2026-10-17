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

    @Environment(\.windowIsVisible) private var windowIsVisible
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        guard item.status == .downloading, let fraction = item.fractionCompleted else { return total }
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
        case .resolving, .downloading, .processing:
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
        case .queued, .choosing, .existing: []
        case .resolving: ["Fetching…"]
        case .downloading: downloadingParts
        case .processing: ["Merging…"]
        case .finished: ["Done"]
        case .failed: [item.asksForSignIn ? "Sign in needed" : "Failed"]
        }
    }

    private var downloadingParts: [String] {
        let speed = Format.speed(item.speedBytesPerSecond)
        guard let fraction = item.fractionCompleted else { return [speed ?? "Starting…"] }
        let percent = "\(Int((fraction * 100).rounded()))%"
        return speed.map { [percent, "-", $0] } ?? [percent]
    }

    // MARK: Failed

    private var failedActions: some View {
        HStack(spacing: 6) {
            if item.asksForSignIn, let onSignIn {
                miniButton(icon: "person.crop.circle", title: "Sign In", action: onSignIn)
            }
            if let onRetry {
                miniButton(icon: "arrow.clockwise", title: "Retry", action: onRetry)
            }
            if !item.asksForSignIn, let onBrowserCapture {
                miniButton(icon: "globe", title: "Browser Capture", action: onBrowserCapture)
            }
        }
        .padding(.trailing, 6)
    }

    private func miniButton(icon: String, title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 9, weight: .bold))
                Text(title).font(.system(size: 10, weight: .bold))
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
