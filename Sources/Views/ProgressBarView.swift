import SwiftUI

struct ProgressBarView: View {
    let item: DownloadItem
    var onRetry: (() -> Void)?
    var onBrowserCapture: (() -> Void)?
    var barHeight: CGFloat = 20

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack(alignment: .leading) {
                track
                fill(width: width)
                if let label {
                    labelText(label)
                        .position(x: labelX(fillWidth: fillWidth(in: width), totalWidth: width), y: barHeight / 2)
                }
            }
            .frame(height: barHeight)
            .overlay(alignment: .trailing) {
                if item.status == .failed {
                    failedActions
                }
            }
        }
        .frame(height: barHeight)
        .animation(.easeOut(duration: 0.3), value: item.status)
    }

    private var track: some View {
        Capsule()
            .fill(Color.white.opacity(0.08))
            .overlay {
                Capsule().strokeBorder(Color.white.opacity(0.07), lineWidth: 1)
            }
    }

    @ViewBuilder
    private func fill(width: CGFloat) -> some View {
        switch item.status {
        case .queued:
            EmptyView()
        case .resolving:
            Capsule()
                .fill(D.progressFill)
                .frame(width: width)
                .opacity(0.4)
        case .downloading:
            if let fraction = item.fractionCompleted {
                Capsule()
                    .fill(D.progressFill)
                    .frame(width: max(width * CGFloat(min(max(fraction, 0), 1)), barHeight))
            } else {
                Capsule()
                    .fill(D.progressFill)
                    .frame(width: width)
                    .opacity(0.45)
            }
        case .processing:
            ProcessingCapsule(width: width)
        case .finished:
            Capsule().fill(D.doneFill).frame(width: width)
        case .failed:
            Capsule().fill(D.failedFill).frame(width: width)
        }
    }

    private struct ProcessingCapsule: View {
        let width: CGFloat

        var body: some View {
            TimelineView(.animation(minimumInterval: 1 / 20)) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate
                Capsule()
                    .fill(D.progressFill)
                    .frame(width: width)
                    .opacity(0.55 + 0.3 * sin(t * 4))
            }
        }
    }

    private func fillWidth(in total: CGFloat) -> CGFloat {
        guard let fraction = item.fractionCompleted else { return 0 }
        return total * CGFloat(min(max(fraction, 0), 1))
    }

    private func labelX(fillWidth edge: CGFloat, totalWidth: CGFloat) -> CGFloat {
        if item.status == .finished || item.status == .failed || item.status == .processing || item.status == .resolving {
            return totalWidth / 2
        }
        let half: CGFloat = 55
        return min(max(edge - 31, half), max(half, totalWidth - half))
    }

    private var label: String? {
        switch item.status {
        case .queued:
            return nil
        case .resolving:
            return "Fetching…"
        case .downloading:
            return progressLabel
        case .processing:
            return "Merging…"
        case .finished:
            return "Done :)"
        case .failed:
            return "Failed :("
        }
    }

    private var progressLabel: String {
        if let fraction = item.fractionCompleted {
            let percent = "\(Int((fraction * 100).rounded()))%"
            if let speed = Format.speed(item.speedBytesPerSecond) {
                return "\(percent) - \(speed)"
            }
            return percent
        }
        if let speed = Format.speed(item.speedBytesPerSecond) {
            return speed
        }
        return "Starting…"
    }

    private func labelText(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundStyle(Color.white.opacity(0.92))
            .lineLimit(1)
            .fixedSize()
    }

    private var failedActions: some View {
        HStack(spacing: 6) {
            if let onRetry {
                miniButton(icon: "arrow.clockwise", title: "Retry", action: onRetry)
            }
            if let onBrowserCapture {
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
