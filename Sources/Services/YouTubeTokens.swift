import Foundation
import WebKit

/// Proof-of-origin tokens for YouTube's video servers. Signed in, YouTube serves some
/// accounts only SABR streams, which yt-dlp can't read, and leaves it the 360p file. Its
/// `web_creator` client still gets every stream, and they download only when the request
/// carries a token from YouTube's BotGuard (`mweb` and `web` stay SABR-only with one). Danny mints one in a hidden
/// `WKWebView` (no Node or Deno), only
/// when a signed-in YouTube run is about to start, and drops the view right after.
/// A token is kept for its run (the probe, the download and a retry share it), since
/// it can be bound to the account and the next run may be signed in as someone else.
@MainActor
final class YouTubeTokens {
    struct Token {
        let value: String
        let expires: Date
    }

    /// By video ID and cookie file: each run writes its own file.
    private var cache: [String: Token] = [:]
    private let mint: (String) async -> Token?

    /// `mint` is replaced in tests, which mustn't reach YouTube.
    init(mint: @escaping (String) async -> Token? = { await YouTubeTokens.mint(for: $0) }) {
        self.mint = mint
    }

    /// `arguments` with a token added when they send YouTube cookies; unchanged otherwise,
    /// or when no token could be minted (the run goes on as before).
    func arguments(_ arguments: [String], for url: URL) async -> [String] {
        guard let flag = arguments.firstIndex(of: "--cookies"), flag + 1 < arguments.count,
              let id = Self.videoID(in: url),
              let token = await token(for: id, session: arguments[flag + 1]) else { return arguments }
        return Self.adding(token, to: arguments)
    }

    func token(for videoID: String, session: String, now: Date = .now) async -> String? {
        let key = videoID + "\t" + session
        if let cached = cache[key], cached.expires > now { return cached.value }
        guard let minted = await mint(videoID) else { return nil }
        cache = cache.filter { $0.value.expires > now }
        cache[key] = minted
        return minted.value
    }

    // MARK: Arguments

    /// yt-dlp keeps only the last `--extractor-args youtube:` it is given, so the token
    /// and its client join the one already there (the retry's clients) or come with
    /// their own, next to the clients yt-dlp picks for a signed-in run.
    nonisolated static func adding(_ token: String, to arguments: [String]) -> [String] {
        let tokenArgument = "po_token=web_creator.gvs+" + token
        var result = arguments
        if let index = result.indices.dropLast().last(where: {
            result[$0] == "--extractor-args" && result[$0 + 1].hasPrefix("youtube:")
        }) {
            result[index + 1] = result[index + 1]
                .replacingOccurrences(of: "player_client=", with: "player_client=web_creator,") + ";" + tokenArgument
        } else {
            result += ["--extractor-args", "youtube:player_client=default,web_creator;" + tokenArgument]
        }
        return result
    }

    /// The video ID in a YouTube link: `watch?v=`, `youtu.be/`, `/shorts/`, `/live/`, `/embed/`.
    static func videoID(in url: URL) -> String? {
        guard SignInSite.site(for: url)?.id == SignInSite.youtube.id else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        let candidate: String? = if url.host()?.hasSuffix("youtu.be") == true {
            parts.first
        } else if parts.first == "watch" {
            URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first { $0.name == "v" }?.value
        } else if parts.count >= 2, ["shorts", "live", "embed"].contains(parts[0]) {
            parts[1]
        } else {
            nil
        }
        guard let candidate, candidate.wholeMatch(of: /[A-Za-z0-9_-]{11}/) != nil else { return nil }
        return candidate
    }

    // MARK: Minting

    /// Runs BotGuard's challenge in a page with YouTube's origin and mints a token for
    /// `videoID`'s run. Nil on any failure; the view goes when this returns. The view
    /// shares the browser's store (WebKit's default), so it reads the watch page as the
    /// signed-in user, the way yt-dlp does with the same cookies.
    static func mint(for videoID: String) async -> Token? {
        let view = WKWebView(frame: .zero, configuration: WKWebViewConfiguration())
        let loader = PageLoader()
        view.navigationDelegate = loader
        await loader.load("<!doctype html><title></title>", in: view, origin: URL(string: "https://www.youtube.com/")!)
        guard let result = try? await view.callAsyncJavaScript(
            mintScript, arguments: ["videoID": videoID], contentWorld: .page,
        ) as? [String: Any], let value = result["token"] as? String,
                                 let lifetime = result["ttl"] as? Double else { return nil }
        // A little early, so a token never runs out mid-download.
        return Token(value: value, expires: .now + max(lifetime - 600, 0))
    }

    private final class PageLoader: NSObject, WKNavigationDelegate {
        private var loaded: CheckedContinuation<Void, Never>?

        func load(_ html: String, in view: WKWebView, origin: URL) async {
            await withCheckedContinuation { continuation in
                loaded = continuation
                view.loadHTMLString(html, baseURL: origin)
            }
        }

        func webView(_: WKWebView, didFinish _: WKNavigation!) { done() }
        func webView(_: WKWebView, didFail _: WKNavigation!, withError _: any Error) { done() }
        func webView(_: WKWebView, didFailProvisionalNavigation _: WKNavigation!, withError _: any Error) { done() }

        private func done() {
            loaded?.resume()
            loaded = nil
        }
    }

    /// BotGuard's web flow, as yt-dlp's PO token providers run it: fetch a challenge,
    /// run its interpreter, take a snapshot, trade it for an integrity token, then mint
    /// for what YouTube binds the token to: the video ID where the session has the
    /// content-bound experiment, else the account's data sync ID (yt-dlp's
    /// `fetch_po_token` makes the same choice). Gives up after 20 s.
    private static let mintScript = #"""
    const requestKey = 'O43z0dpjhgX20SCx4KAo';
    const jnn = async (method, body) => {
        const response = await fetch('https://www.youtube.com/api/jnn/v1/' + method, {
            method: 'POST',
            headers: {
                'content-type': 'application/json+protobuf',
                'x-goog-api-key': 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw',
                'x-user-agent': 'grpc-web-javascript/0.1',
            },
            body: JSON.stringify(body),
        });
        if (!response.ok) throw new Error(method + ' ' + response.status);
        return response.json();
    };
    const fromBase64 = (text) => Uint8Array.from(
        atob(text.replace(/-/g, '+').replace(/_/g, '/').padEnd(Math.ceil(text.length / 4) * 4, '=')),
        (c) => c.charCodeAt(0));
    const toBase64Url = (bytes) => btoa(String.fromCharCode(...bytes)).replace(/\+/g, '-').replace(/\//g, '_');
    const mint = async () => {
        const page = await (await fetch('/watch?v=' + encodeURIComponent(videoID))).text();
        const contentBound = /html5_generate_content_po_token(=|\\u003d)true/.test(page);
        const dataSyncID = page.match(/"DATASYNC_ID":"([^"|]+)/)?.[1];
        const identifier = contentBound || !dataSyncID ? videoID : dataSyncID;
        const raw = await jnn('Create', [requestKey]);
        const challenge = raw.length > 1 && typeof raw[1] === 'string'
            ? JSON.parse(new TextDecoder().decode(fromBase64(raw[1]).map((b) => b + 97)))
            : raw[0];
        const [, wrappedScript, wrappedURL, , program, globalName] = challenge;
        const script = wrappedScript?.find((v) => typeof v === 'string');
        if (script) {
            new Function(script)();
        } else {
            const url = wrappedURL?.find((v) => typeof v === 'string');
            await new Promise((resolve, reject) => {
                const tag = document.createElement('script');
                tag.src = url.startsWith('//') ? 'https:' + url : url;
                tag.onload = resolve;
                tag.onerror = () => reject(new Error('interpreter'));
                document.head.appendChild(tag);
            });
        }
        const vm = globalThis[globalName];
        if (!vm?.a) throw new Error('no BotGuard');
        const snapshot = await new Promise((resolve) => {
            vm.a(program, (asyncSnapshot) => resolve(asyncSnapshot), true, undefined, () => {}, [[], []]);
        });
        const signals = [];
        const response = await new Promise((resolve) => snapshot(resolve, [undefined, undefined, signals, undefined]));
        const [integrityToken, ttl] = await jnn('GenerateIT', [requestKey, response]);
        const minter = await signals[0](fromBase64(integrityToken));
        const token = toBase64Url(await minter(new TextEncoder().encode(identifier)));
        return { token, ttl: Number(ttl) };
    };
    return await Promise.race([
        mint(),
        new Promise((_, reject) => setTimeout(() => reject(new Error('timed out')), 20000)),
    ]);
    """#
}
