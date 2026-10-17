import QuickLook
import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(DownloadManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(SiteSessions.self) private var sessions
    @Environment(\.openWindow) private var openWindow

    @State private var showConsentAlert = false
    @State private var pendingSnifferURL: URL?
    @State private var manualURL = ""
    @State private var isSearching = false
    @State private var isDropTargeted = false
    /// The last clicked card, so Space knows what to preview. Clicks only: arrow keys are the keyboard task.
    @State private var selection: DownloadItem.ID?
    @State private var previewURL: URL?
    @FocusState private var listFocused: Bool

    var body: some View {
        @Bindable var manager = manager
        return ZStack {
            WindowBackground()
            listArea
        }
        .ignoresSafeArea()
        .trackingWindowVisibility()
        .alert("Open the capture browser?", isPresented: $showConsentAlert) {
            Button("Open Browser") {
                settings.browserConsentGiven = true
                if let url = pendingSnifferURL {
                    model.snifferStartURL = url
                    pendingSnifferURL = nil
                }
                openWindow(id: "sniffer")
            }
            Button("Not Now", role: .cancel) {}
        } message: {
            Text("""
            Danny will open a built-in browser window. While you browse, it lists every video \
            file and HLS stream it detects, so you can pick one to download. Only use this with \
            content you have permission to download.
            """)
        }
        .sheet(isPresented: $manager.pendingManualAdd) {
            AddURLSheet(url: $manualURL) { url in
                _ = manager.add(url: url)
                manualURL = ""
            }
        }
        .task {
            model.watcher.start()
            #if DEBUG
                // `-sample-search <text>` (debug builds): open the search with this text.
                if let text = UserDefaults.standard.string(forKey: "sample-search") {
                    manager.filter.text = text
                    isSearching = true
                }
                // `-sample-clipboard <link>` (debug builds): offer this link in the toast.
                if let link = UserDefaults.standard.string(forKey: "sample-clipboard") {
                    model.watcher.offer = URL(string: link)
                }
                // `-sample-drop` (debug builds): show the drop highlight.
                if ProcessInfo.processInfo.arguments.contains("-sample-drop") {
                    isDropTargeted = true
                }
                // `-sample-sign-in <site id>` (debug builds): open that site's sign-in window.
                if let id = UserDefaults.standard.string(forKey: "sample-sign-in"),
                   let site = sessions.sites.first(where: { $0.id == id })
                {
                    openWindow(id: SignInView.windowID, value: site)
                }
            #endif
        }
    }

    private var topBars: some View {
        @Bindable var manager = manager
        return VStack(spacing: 0) {
            TitleBarView(
                filter: $manager.filter,
                isSearching: $isSearching,
                matchCount: manager.visibleItems.count,
                totalCount: manager.items.count,
                onDownload: { manager.add(url: $0) },
            )
            if isSearching {
                SearchScopeBar(
                    filter: $manager.filter,
                    counts: manager.filter.counts(in: manager.items),
                    sites: DownloadFilter.sites(in: manager.items, keeping: manager.filter.site),
                )
                .padding(.bottom, 6)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
    }

    private var listArea: some View {
        @Bindable var manager = manager
        return ZStack(alignment: .bottom) {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: D.Spacing.list) {
                    ForEach(manager.visibleItems) { item in
                        DownloadCardView(
                            item: item,
                            onRemove: { manager.remove(id: item.id) },
                            onCancel: { manager.cancel(id: item.id) },
                            onRetry: { manager.retry(id: item.id) },
                            onReveal: { manager.revealInFinder(id: item.id) },
                            onBrowserCapture: { requestBrowser(url: item.sourceURL) },
                            onOpen: { manager.open(id: item.id) },
                            onCopyLink: { model.watcher.copy(item.sourceURL) },
                            isSelected: selection == item.id,
                            onSignIn: signInAction(for: item),
                            onChoose: { manager.choose(id: item.id, choice: $0) },
                            onResolveExisting: { manager.resolveExisting(id: item.id, with: $0) },
                            onKeepExisting: {
                                manager.keepExisting(id: item.id)
                                manager.revealInFinder(id: item.id)
                            },
                        )
                        .onTapGesture(count: 2) { manager.open(id: item.id) }
                        .simultaneousGesture(TapGesture().onEnded {
                            selection = item.id
                            listFocused = true
                        })
                    }
                    if manager.visibleItems.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, D.Spacing.listInset)
                .padding(.top, D.Spacing.listTop)
                .padding(.bottom, 68)
            }
            .overlay {
                if isDropTargeted {
                    DropHighlight()
                        .padding([.horizontal, .bottom], D.Spacing.listInset)
                        .padding(.bottom, 52) // clear of the bottom bar
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
            }
            .animation(.easeOut(duration: 0.15), value: isDropTargeted)
            .animation(.easeOut(duration: 0.2), value: model.watcher.offer)
            // ⌘V with no text field focused adds the clipboard's link.
            .focusable()
            .focusEffectDisabled()
            .focused($listFocused)
            .onKeyPress(.space) {
                if previewURL != nil {
                    previewURL = nil
                    return .handled
                }
                previewURL = manager.visibleItems.previewURL(selection: selection)
                return previewURL == nil ? .ignored : .handled
            }
            .quickLookPreview($previewURL)
            .onPasteCommand(of: [.url, .plainText]) { _ in pasteFromClipboard() }
            .dropDestination(for: DroppedLink.self) { links, _ in
                for link in links {
                    manager.add(url: link.url)
                }
                return !links.isEmpty
            } isTargeted: { isDropTargeted = $0 }
            // The bars float over the list; cards scroll under them through the
            // system's soft edge, a blurred fade drawn by the compositor.
            .safeAreaBar(edge: .top, spacing: 0) { topBars }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .defaultScrollAnchor(.top)

            if let offer = model.watcher.offer {
                ClipboardToast(
                    url: offer,
                    onAccept: model.watcher.acceptOffer,
                    onDismiss: model.watcher.dismissOffer,
                )
                .padding(.horizontal, D.Spacing.listInset)
                .padding(.bottom, 60) // above the bottom bar
                .transition(.opacity)
            }

            BottomBarView(
                sortOrder: $manager.sortOrder,
                onBrowser: { requestBrowser(url: nil) },
                onPaste: pasteFromClipboard,
                onEnterURL: { manager.pendingManualAdd = true },
            )
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(manager.filter.isEmpty ? "icon-plus" : "icon-search")
                .resizable()
                .frame(width: 28, height: 28)
                .opacity(0.3)
            Text(emptyTitle)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.35))
            if manager.filter.link != nil, !manager.filter.linkIsListed(in: manager.items) {
                Text("Press Return to download it")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.22))
            } else if manager.filter.isEmpty {
                Text("Paste a URL, or use Browser Capture for tricky sites")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.22))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 120)
    }

    private var emptyTitle: String {
        let filter = manager.filter
        if filter.link != nil {
            return filter.linkIsListed(in: manager.items)
                ? "No downloads match these filters" : "Not in your downloads yet"
        }
        if filter.isEmpty { return "Press + to add a video link" }
        let text = filter.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Nothing here" : "No downloads match “\(text)”"
    }

    /// Opens the sign-in window for the item's site; nil when the site is unknown.
    private func signInAction(for item: DownloadItem) -> (() -> Void)? {
        guard let site = sessions.site(for: item.sourceURL) else { return nil }
        return { openWindow(id: SignInView.windowID, value: site) }
    }

    private func requestBrowser(url: URL?) {
        if settings.browserConsentGiven {
            model.snifferStartURL = url
            openWindow(id: "sniffer")
        } else {
            pendingSnifferURL = url
            showConsentAlert = true
        }
    }

    private func pasteFromClipboard() {
        guard let url = LinkIntake.pasteboardLink() else { return }
        manager.add(url: url)
    }
}

struct AddURLSheet: View {
    @Binding var url: String
    let onAdd: (URL) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Download from URL")
                .font(.system(size: 15, weight: .bold))
            TextField("https://…", text: $url)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .onSubmit(submit)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { submit() }
                    .keyboardShortcut(.defaultAction)
                    .tint(.purple)
            }
        }
        .padding(18)
        .frame(width: 420)
    }

    private func submit() {
        guard let trimmed = URL(string: url.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = trimmed.scheme?.lowercased(), ["http", "https"].contains(scheme)
        else { return }
        onAdd(trimmed)
        dismiss()
    }
}
