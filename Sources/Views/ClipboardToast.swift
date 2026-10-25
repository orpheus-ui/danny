import SwiftUI

/// Offers a link copied in another app: one glass capsule above the bottom bar.
/// Return downloads it, Escape or the close button dismisses it, and it fades on
/// its own after a few seconds.
struct ClipboardToast: View {
    let url: URL
    let onAccept: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("Download \(Self.shortLink(url))?")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(D.textPrimary.opacity(0.9))
                .lineLimit(1)
                .truncationMode(.middle)
            Button("Download", action: onAccept)
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(D.accent)
                .controlSize(.small)
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(D.textSecondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.cancelAction)
            .accessibilityLabel("Dismiss")
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .padding(.vertical, 7)
        .dannyGlass(in: Capsule())
        .task(id: url) {
            try? await Task.sleep(for: .seconds(6))
            if !Task.isCancelled { onDismiss() }
        }
    }

    /// `youtube.com/watch?v=…`: the host without `www.`, then the rest of the link.
    static func shortLink(_ url: URL) -> String {
        let link = url.absoluteString
        guard let host = url.host(), let range = link.range(of: host) else { return link }
        return (host.hasPrefix("www.") ? String(host.dropFirst(4)) : host) + link[range.upperBound...]
    }
}
