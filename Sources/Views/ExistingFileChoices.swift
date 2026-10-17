import SwiftUI

/// The card's question when the video is already in the folder, in the quality
/// chips' style. No countdown: replacing a file waits for an answer.
struct ExistingFileChoices: View {
    let existing: ExistingFile
    let onResolve: (ExistingFilePolicy) -> Void
    let onKeep: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Text(summary)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(D.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .layoutPriority(-1)
            Spacer(minLength: 4)
            chip("Replace", help: "Move the file you have to the Trash and download again") {
                onResolve(.replace)
            }
            chip("Keep Both", isPrimary: true, help: "Download again beside the file you have") {
                onResolve(.keepBoth)
            }
            chip("Show in Finder", help: "Keep the file you have and show it") { onKeep() }
        }
        .frame(height: 24)
    }

    private var summary: String {
        existing.resolution.map { "You already have this · \($0)" } ?? "You already have this"
    }

    private func chip(
        _ title: String, isPrimary: Bool = false, help: String, action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .frame(height: 24)
                .background(Capsule()
                    .fill(isPrimary ? AnyShapeStyle(D.progressFill) : AnyShapeStyle(.black.opacity(0.45))))
                .overlay { Capsule().strokeBorder(.white.opacity(isPrimary ? 0.25 : 0.12)) }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .fixedSize()
        .help(help)
    }
}
