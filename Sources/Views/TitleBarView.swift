import SwiftUI

struct TitleBarView: View {
    @Binding var query: String
    @State private var searchActive = false
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        ZStack {
            D.titlebarFade
                .frame(height: 60)
                .allowsHitTesting(false)

            HStack(spacing: 8) {
                Color.clear.frame(width: 64)
                Spacer()
                titleBlock
                Spacer()
                toolbarButtons
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 60)
        .overlay(alignment: .top) {
            if searchActive { searchField }
        }
    }

    private var titleBlock: some View {
        HStack(alignment: .center, spacing: 2) {
            Text("Danny")
                .font(D.Font.appTitle)
                .foregroundStyle(D.titleGradient)
            Ellipse()
                .fill(D.accent)
                .frame(width: 5, height: 7)
                .blur(radius: 6)
                .offset(y: -4)
        }
        .allowsHitTesting(false)
    }

    private var toolbarButtons: some View {
        HStack(spacing: D.Spacing.toolbar) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) {
                    if searchActive { query = "" }
                    searchActive.toggle()
                }
            } label: {
                Image("icon-search")
                    .resizable()
                    .frame(width: D.Size.toolbarIcon, height: D.Size.toolbarIcon)
                    .opacity(searchActive ? 1 : 0.9)
            }
            .buttonStyle(.plain)
            .help("Search downloads")

            Button {
                openSettings()
            } label: {
                Image("icon-settings")
                    .resizable()
                    .frame(width: D.Size.toolbarIcon, height: D.Size.toolbarIcon)
            }
            .buttonStyle(.plain)
            .help("Settings")
        }
    }

    private var searchField: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.5))
            TextField("Filter downloads", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.9))
                .onSubmit {}
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Capsule().fill(D.ink.opacity(0.85)).overlay(Capsule().strokeBorder(Color.white.opacity(0.14))))
        .frame(width: 280)
        .padding(.top, 34)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onExitCommand {
            query = ""
            searchActive = false
        }
    }
}
