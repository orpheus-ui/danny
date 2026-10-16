import Foundation

/// How a failed run is retried and explained on the card.
extension DownloadManager {
    /// The YouTube clients the retry asks for. yt-dlp drops clients that can't send
    /// cookies, so a signed-in retry can't use the iOS client.
    static func fallbackArguments(signedIn: Bool) -> [String] {
        ["--extractor-args", "youtube:player_client=" + (signedIn ? "tv,mweb" : "ios")]
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
