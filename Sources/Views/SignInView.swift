import SwiftUI
import WebKit

/// The sign-in window: the site's own login page in Danny's browser. The password
/// goes to the site; Danny only notices the session it leaves behind.
struct SignInView: View {
    static let windowID = "sign-in"

    let site: SignInSite

    @Environment(SiteSessions.self) private var sessions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            header
            SignInWebView(url: site.loginURL)
        }
        .background(WindowBackground())
        .ignoresSafeArea(edges: .top)
        .navigationTitle("Sign in to \(site.name)")
    }

    private var signedIn: Bool { sessions.isSignedIn(site) }

    private var header: some View {
        HStack(spacing: 12) {
            SiteBadge(site: site, size: 34)
            VStack(alignment: .leading, spacing: 2) {
                Text(signedIn ? "Signed in to \(site.name)" : "Sign in to \(site.name)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(D.textPrimary)
                    .contentTransition(.opacity)
                Text("Your password goes straight to \(site.name). Danny keeps only the session, on this Mac.")
                    .font(.system(size: 11))
                    .foregroundStyle(D.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 12)
            Button(signedIn ? "Done" : "Cancel") { dismiss() }
                .buttonStyle(.plain)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .frame(height: 28)
                .background(Capsule().fill(signedIn ? D.doneEnd : Color.white.opacity(0.1)))
                .keyboardShortcut(signedIn ? .defaultAction : .cancelAction)
        }
        .padding(.horizontal, 16)
        .padding(.top, D.Size.titleLine * 2)
        .padding(.bottom, 12)
        .animation(.smooth(duration: 0.3), value: signedIn)
    }
}

/// A round monogram in the site's color; brand logos aren't bundled.
struct SiteBadge: View {
    let site: SignInSite
    var size: CGFloat = 28

    var body: some View {
        Text(monogram)
            .font(.system(size: size * 0.42, weight: .heavy, design: .rounded))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Circle().fill(color.gradient))
            .accessibilityHidden(true)
    }

    private var monogram: String {
        switch site.id {
        case "youtube": "▶"
        case "x": "X"
        default: String(site.name.prefix(1))
        }
    }

    private var color: Color {
        switch site.id {
        case "youtube": Color(red: 0.93, green: 0.16, blue: 0.16)
        case "instagram": Color(red: 0.82, green: 0.2, blue: 0.55)
        case "facebook": Color(red: 0.1, green: 0.47, blue: 0.95)
        default: Color(white: 0.2)
        }
    }
}

private struct SignInWebView: NSViewRepresentable {
    let url: URL

    /// Sign-in pages turn away browsers they don't recognize; Danny's browser
    /// presents itself as Safari, which it is underneath.
    private static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) "
        + "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/26.0 Safari/605.1.15"

    func makeNSView(context _: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.customUserAgent = Self.userAgent
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_: WKWebView, context _: Context) {}
}
