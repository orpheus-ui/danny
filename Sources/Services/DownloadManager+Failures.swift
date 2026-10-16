import Foundation

/// How a failed run is retried and explained on the card.
extension DownloadManager {
    /// The YouTube clients the retry asks for. yt-dlp drops clients that can't send
    /// cookies, so a signed-in retry can't use the iOS client.
    static func fallbackArguments(signedIn: Bool) -> [String] {
        ["--extractor-args", "youtube:player_client=" + (signedIn ? "tv,mweb" : "ios")]
    }

    /// The cookies a run tries first: none for a site that signs in only when asked.
    static func firstTryCookies(for url: URL, signedIn cookies: [String]) -> [String] {
        SignInSite.site(for: url)?.signsInOnlyWhenAsked == true ? [] : cookies
    }

    /// The retry's arguments: other YouTube clients, plus the session's cookies when a
    /// signed-out try was asked to sign in.
    static func retryArguments(after message: String, tried: [String], signedIn: [String]) -> [String] {
        let wasSignedOut = !tried.contains("--cookies")
        let retry = (wasSignedOut && DownloadItem.asksForSignIn(message) ? signedIn : []) + tried
        return retry + fallbackArguments(signedIn: retry.contains("--cookies"))
    }

    static func shouldRetryWithFallback(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("403")
            || lowered.contains("confirm you")
            || lowered.contains("sign in to confirm")
    }

    /// `updates`: whether Danny fetches the latest yt-dlp when it opens.
    static func hinted(_ message: String, updates: Bool) -> String {
        // The card offers Sign In for these; an update doesn't help.
        if DownloadItem.asksForSignIn(message) { return message }
        let lowered = message.lowercased()
        if lowered.contains("403") {
            let fix = updates
                ? "reopen Danny to get the latest"
                : "turn on Keep yt-dlp up to date in Settings › Engine and reopen Danny"
            return message + "\nThis usually means yt-dlp needs an update: \(fix), then retry."
        }
        return message
    }
}
