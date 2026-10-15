import SwiftUI

/// The title bar. Searching turns the title into one glass field that finds and adds:
/// type to filter the list, paste a link and press Return to download it.
struct TitleBarView: View {
    @Binding var filter: DownloadFilter
    @Binding var isSearching: Bool
    /// Items matching the filter, and all items, for the "3 of 12" count.
    let matchCount: Int
    let totalCount: Int
    let onDownload: (URL) -> Void

    @FocusState private var fieldFocused: Bool
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        // Everything sits on one line, `D.Size.titleLine` from the top, with the
        // traffic lights (moved there by `windowTranslucency()`).
        ZStack {
            HStack(spacing: 8) {
                Color.clear.frame(width: 64)
                Spacer()
                toolbarButtons
            }
            .padding(.horizontal, 15)

            if isSearching {
                searchField
                    .transition(.blurReplace.combined(with: .scale(0.96)))
            } else {
                titleBlock
                    .transition(.blurReplace)
            }
        }
        .frame(height: D.Size.titleLine * 2)
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
            Button(action: toggleSearch) {
                Image("icon-search")
                    .resizable()
                    .frame(width: D.Size.toolbarIcon, height: D.Size.toolbarIcon)
                    .opacity(isSearching ? 1 : 0.9)
            }
            .buttonStyle(.plain)
            .keyboardShortcut("f", modifiers: .command)
            .help("Search or add a link (⌘F)")

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

    // MARK: Search field

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: filter.link == nil ? "magnifyingglass" : "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(filter.link == nil ? D.textSecondary : D.accent)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 14)

            TextField("Search downloads or paste a link", text: $filter.text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(D.textPrimary)
                .focused($fieldFocused)
                .onSubmit(submit)
                .onExitCommand(perform: escape)

            trailingAccessory
        }
        .padding(.leading, 12)
        .padding(.trailing, 5)
        .frame(width: 340, height: 32)
        .dannyGlass(tint: D.ink.opacity(0.35), in: Capsule())
        .onAppear { fieldFocused = true }
    }

    @ViewBuilder private var trailingAccessory: some View {
        if let link = filter.link {
            Button { download(link) } label: {
                HStack(spacing: 4) {
                    Image(systemName: "return")
                    Text("Download")
                }
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 9)
                .frame(height: 22)
                .background(Capsule().fill(D.accent))
            }
            .buttonStyle(.plain)
            .help("Download this link")
        } else if !filter.text.isEmpty {
            HStack(spacing: 6) {
                Text("\(matchCount) of \(totalCount)")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundStyle(D.textSecondary)
                    .contentTransition(.numericText())
                Button {
                    filter.text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(D.textSecondary)
                }
                .buttonStyle(.plain)
                .help("Clear")
            }
            .padding(.trailing, 5)
        }
    }

    // MARK: Actions

    private func toggleSearch() {
        withAnimation(.smooth(duration: 0.25)) {
            if isSearching { filter = DownloadFilter() }
            isSearching.toggle()
        }
    }

    private func submit() {
        if let link = filter.link { download(link) }
    }

    private func download(_ link: URL) {
        onDownload(link)
        filter.text = ""
    }

    /// Esc clears the text first, then closes the search.
    private func escape() {
        if filter.text.isEmpty {
            toggleSearch()
        } else {
            filter.text = ""
        }
    }
}

/// Under the title bar while searching: status scopes with counts, then the sites
/// that appear most in the list.
struct SearchScopeBar: View {
    @Binding var filter: DownloadFilter
    let counts: [DownloadFilter.Scope: Int]
    let sites: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(DownloadFilter.Scope.allCases) { scope in
                    chip(scope.label, count: counts[scope] ?? 0, selected: filter.scope == scope) {
                        filter.scope = scope
                    }
                }
                if !sites.isEmpty {
                    Circle()
                        .fill(D.textSecondary)
                        .frame(width: 3, height: 3)
                        .padding(.horizontal, 4)
                    ForEach(sites, id: \.self) { site in
                        chip(site, selected: filter.site == site) {
                            filter.site = filter.site == site ? nil : site
                        }
                    }
                }
            }
            .padding(.horizontal, D.Spacing.listInset)
        }
        .frame(height: 30)
        .animation(.smooth(duration: 0.2), value: filter)
    }

    private func chip(
        _ title: String,
        count: Int? = nil,
        selected: Bool,
        action: @escaping () -> Void,
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .monospacedDigit()
                        .foregroundStyle(selected ? .white.opacity(0.75) : D.textSecondary)
                }
            }
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(selected ? .white : .white.opacity(0.8))
            .padding(.horizontal, 10)
            .frame(height: 24)
            .background(Capsule().fill(selected ? D.accent : Color.white.opacity(0.07)))
            .overlay { Capsule().strokeBorder(Color.white.opacity(selected ? 0 : 0.1)) }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}
