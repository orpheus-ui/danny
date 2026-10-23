import SwiftUI

struct BottomBarView: View {
    @Binding var sortOrder: SortOrder
    var onBrowser: () -> Void
    var onPaste: () -> Void
    var onEnterURL: () -> Void
    /// The activity pill beside Sort; nil hides it.
    var activity: QueueActivity?
    var canPauseAll = true
    var canResumeAll = false
    var onPauseAll: () -> Void = {}
    var onResumeAll: () -> Void = {}

    var body: some View {
        ZStack {
            D.bottomFade
                .allowsHitTesting(false)

            // One container, so the bar's glass shares a single backdrop pass.
            GlassEffectContainer {
                HStack(spacing: 10) {
                    sortMenu
                    if let activity {
                        ActivityPill(
                            activity: activity, canPauseAll: canPauseAll, canResumeAll: canResumeAll,
                            onPauseAll: onPauseAll, onResumeAll: onResumeAll,
                        )
                    }
                    Spacer()
                    PillButton(icon: "icon-browser", style: .bar) {
                        onBrowser()
                    }
                    .help("Browser Capture")

                    PillMenu(icon: "icon-plus", style: .bar) {
                        Button("Paste from Clipboard", action: onPaste)
                        Button("Enter URL…", action: onEnterURL)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: D.Size.bottomBar)
    }

    private var sortMenu: some View {
        PillMenu(icon: "icon-arrows-sort", style: .bar) {
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.inline)
        }
        .help("Sort downloads")
    }
}
