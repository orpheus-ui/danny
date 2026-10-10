import SwiftUI
import WebKit

struct SnifferBrowserScreen: View {
    @Environment(AppSettings.self) private var settings
    @Environment(DownloadManager.self) private var manager
    @Environment(AppModel.self) private var model

    @State private var store = SnifferStore()
    @State private var addressField = ""
    @State private var startURL = SnifferBrowserScreen.initialURL()
    @State private var reference = WebViewReference()

    static func initialURL() -> URL {
        if let text = NSPasteboard.general.string(forType: .string),
           let url = ClipboardWatcher.firstURL(in: text)
        {
            return url
        }
        return URL(string: "https://duckduckgo.com")!
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                toolbar
                Divider().opacity(0.15)
                MediaSnifferWebView(
                    startURL: startURL,
                    reference: reference,
                    onCaptured: { store.capture(rawURL: $0) },
                    onCommitted: { url in
                        currentURLSync(url)
                    },
                )
            }
            Divider().opacity(0.2)
            sidebar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 860, minHeight: 540)
        .task(id: model.snifferStartURL) {
            if let url = model.snifferStartURL {
                model.snifferStartURL = nil
                addressField = url.absoluteString
                reference.webView?.load(URLRequest(url: url))
            }
        }
    }

    private func currentURLSync(_ url: URL?) {
        addressField = url?.absoluteString ?? ""
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            Button {
                _ = reference.webView?.goBack()
            } label: {
                Image(systemName: "chevron.left")
            }
            .disabled(reference.webView?.canGoBack != true)

            Button {
                _ = reference.webView?.goForward()
            } label: {
                Image(systemName: "chevron.right")
            }
            .disabled(reference.webView?.canGoForward != true)

            Button {
                reference.webView?.reload()
            } label: {
                Image(systemName: "arrow.clockwise")
            }

            HStack(spacing: 4) {
                Image(systemName: "lock")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                TextField("Search or enter address", text: $addressField)
                    .textFieldStyle(.plain)
                    .font(.system(size: 12))
                    .onSubmit(go)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.primary.opacity(0.06)))

            Button("Send to Danny") {
                if let url = resolvedAddressURL {
                    _ = manager.add(url: url)
                }
            }
            .controlSize(.small)
            .disabled(resolvedAddressURL == nil)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .buttonStyle(.plain)
    }

    private var resolvedAddressURL: URL? {
        if let url = URL(string: addressField.trimmingCharacters(in: .whitespaces)),
           ["http", "https"].contains(url.scheme?.lowercased() ?? "")
        {
            return url
        }
        return URL(
            string: "https://duckduckgo.com/?q=\(addressField.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? "")",
        )
    }

    private func go() {
        guard let url = resolvedAddressURL else { return }
        reference.webView?.load(URLRequest(url: url))
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 6) {
                Image("icon-browser")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .opacity(0.7)
                Text("Captured Media")
                    .font(.system(size: 12, weight: .semibold))
                Text("\(store.captured.count)")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(D.accent.opacity(0.30)))
                Spacer()
                Button("Clear") { store.clear() }
                    .controlSize(.small)
                    .disabled(store.captured.isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider().opacity(0.15)

            if store.captured.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "dot.radiowaves.up.forward")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("Play a video in the page.\nDetected streams appear here.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(store.captured) { media in
                            CapturedMediaRow(media: media) {
                                _ = manager.add(url: media.url)
                            }
                        }
                    }
                    .padding(8)
                }
            }
        }
        .frame(width: 280)
        .background(Color.primary.opacity(0.04))
    }
}

final class WebViewReference {
    weak var webView: WKWebView?
}

struct CapturedMediaRow: View {
    let media: CapturedMedia
    let onAdd: () -> Void

    @State private var copied = false

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(media.kind.label)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(kindColor)
                Text(host)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.primary.opacity(0.85))
                    .lineLimit(1)
                Text(path)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            Spacer(minLength: 4)
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(media.url.absoluteString, forType: .string)
                copied = true
                Task {
                    try? await Task.sleep(for: .seconds(1.2))
                    copied = false
                }
            } label: {
                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Copy URL")

            Button(action: onAdd) {
                Image("icon-plus")
                    .resizable()
                    .frame(width: 14, height: 14)
                    .padding(5)
                    .background(Circle().fill(D.accent.opacity(0.25)))
            }
            .buttonStyle(.plain)
            .help("Download with Danny")
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.05)),
        )
    }

    private var host: String {
        media.url.host ?? media.url.absoluteString
    }

    private var path: String {
        let path = media.url.path.isEmpty ? "/" : media.url.path
        let query = media.url.query.map { "?\($0)" } ?? ""
        return String((path + query).suffix(60))
    }

    private var kindColor: Color {
        switch media.kind {
        case .hls: Color(red: 22 / 255, green: 219 / 255, blue: 160 / 255)
        case .dash: .orange
        case .video: D.accent
        case .audio: .pink
        case .other: .gray
        }
    }
}
