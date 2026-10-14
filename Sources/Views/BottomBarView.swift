import SwiftUI

struct BottomBarView: View {
    @Binding var sortOrder: SortOrder
    var onBrowser: () -> Void
    var onPaste: () -> Void
    var onEnterURL: () -> Void

    var body: some View {
        ZStack(alignment: .top) {
            D.bottomFade
                .frame(height: 80)
                .offset(y: -24)
                .allowsHitTesting(false)

            HStack(spacing: 10) {
                sortMenu
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
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
        }
        .frame(height: 56)
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
