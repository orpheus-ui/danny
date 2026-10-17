import Foundation

/// What yt-dlp's error output means for the person: a short reason and the one thing
/// worth trying. The raw output stays on the item for bug reports.
struct FailureReason: Equatable {
    nonisolated enum Action: Equatable, Sendable {
        /// Open the site's sign-in window.
        case signIn
        case browserCapture
        case retry
        /// Trying again can't help.
        case nothing
    }

    let text: String
    let action: Action

    init(_ message: String) {
        let lowered = message.lowercased().replacingOccurrences(of: "’", with: "'")
        func mentions(_ phrases: [String]) -> Bool { phrases.contains { lowered.contains($0) } }
        // Sign-in comes first: "Private video. Sign in if you've been granted access" can be
        // fixed by signing in, and the retry with the session's cookies relies on the same test.
        if DownloadItem.asksForSignIn(message) {
            self = .init("Sign in needed", .signIn)
        } else if mentions(["is private", "private video"]) {
            self = .init("Private video", .nothing)
            // Before "unavailable": "HTTP Error 503: Service Unavailable" is a server hiccup.
        } else if mentions([
            "nodename nor servname", "name or service not known", "temporary failure in name resolution",
            "timed out", "network is unreachable", "no route to host", "connection reset", "connection refused",
            "internet connection appears to be offline", "http error 429", "http error 5",
        ]) {
            self = .init("Network problem", .retry)
        } else if mentions([
            "unavailable", "not available", "no longer available", "has been removed", "has been deleted",
            "geo restriction", "http error 404", "http error 410",
        ]) {
            self = .init("Video unavailable", .nothing)
        } else if mentions(["unsupported url"]) {
            self = .init("Site not supported", .browserCapture)
        } else {
            self = .init("Download failed", .retry)
        }
    }

    private init(_ text: String, _ action: Action) {
        self.text = text
        self.action = action
    }
}

extension DownloadItem {
    var failureReason: FailureReason? {
        status == .failed ? FailureReason(errorMessage ?? "") : nil
    }
}
