import SwiftUI

struct MainWindow: View {
    @Environment(AppModel.self) private var model
    @Environment(DownloadManager.self) private var manager
    @Environment(AppSettings.self) private var settings
    @Environment(\.openWindow) private var openWindow

    @State private var showConsentAlert = false
    @State private var pendingSnifferURL: URL?
    @State private var manualURL = ""
    @State private var isSearching = false

    var body: some View {
        @Bindable var manager = manager
        return ZStack {
            LiquidWindowBackground()
            VStack(spacing: 0) {
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
                listArea
            }
        }
        .ignoresSafeArea()
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
            #endif
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
                        )
                    }
                    if manager.visibleItems.isEmpty {
                        emptyState
                    }
                }
                .padding(.horizontal, D.Spacing.listInset)
                .padding(.top, 4)
                .padding(.bottom, 68)
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
            if manager.filter.link != nil {
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
        if filter.link != nil { return "Not in your downloads yet" }
        if filter.isEmpty { return "Press + to add a video link" }
        let text = filter.text.trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? "Nothing here" : "No downloads match “\(text)”"
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
        guard let string = NSPasteboard.general.string(forType: .string),
              let url = ClipboardWatcher.firstURL(in: string)
        else { return }
        _ = manager.add(url: url)
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
