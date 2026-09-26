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
                PillButton(icon: "icon-browser", iconSize: 24, padding: 8) {
                    onBrowser()
                }
                .help("Browser Capture")

                PillMenu(icon: "icon-plus", iconSize: 24, padding: 8) {
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
        Menu {
            Picker("Sort", selection: $sortOrder) {
                ForEach(SortOrder.allCases) { order in
                    Text(order.label).tag(order)
                }
            }
            .pickerStyle(.inline)
        } label: {
            Image("icon-arrows-sort")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 24, height: 24)
                .padding(8)
                .dannyGlass(tint: Color.black.opacity(0.30), in: .capsule, interactive: true)
        }
        .menuStyle(.button)
        .menuIndicator(.hidden)
        .buttonStyle(.plain)
        .fixedSize()
        .help("Sort downloads")
    }
}
