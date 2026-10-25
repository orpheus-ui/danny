@testable import Danny
import Foundation
import Testing

struct FailureReasonTests {
    nonisolated struct Case: Sendable {
        let line: String
        let text: String
        let action: FailureReason.Action

        init(_ line: String, _ text: String, _ action: FailureReason.Action) {
            self.line = line
            self.text = text
            self.action = action
        }
    }

    /// Lines as yt-dlp prints them: the extractor prefix, then the message.
    nonisolated static let cases: [Case] = [
        Case(
            "ERROR: [youtube] abc: Sign in to confirm you’re not a bot. Use --cookies-from-browser or --cookies",
            "Sign in needed",
            .signIn,
        ),
        Case(
            "ERROR: [youtube] abc: Sign in to confirm your age. This video may be inappropriate for some users.",
            "Sign in needed",
            .signIn,
        ),
        Case(
            "ERROR: [youtube] abc: Private video. Sign in if you've been granted access to this video",
            "Sign in needed",
            .signIn,
        ),
        Case(
            "ERROR: [vimeo] 1: This video is only available for registered users. Use --username and --password",
            "Sign in needed",
            .signIn,
        ),
        Case("ERROR: [redtube] 1: Video is private", "Private video", .nothing),
        Case("ERROR: [screencastomatic] 1: This video is private and requires a password", "Private video", .nothing),
        Case("ERROR: [youtube] abc: Video unavailable", "Video unavailable", .nothing),
        Case("ERROR: [youtube] abc: This video is not available", "Video unavailable", .nothing),
        Case("ERROR: [youtube] abc: This video has been removed by the uploader", "Video unavailable", .nothing),
        Case("ERROR: [vgtv] 1: Video 1 is no longer available", "Video unavailable", .nothing),
        Case(
            "ERROR: [generic] This video is not available from your location due to geo restriction",
            "Video unavailable",
            .nothing,
        ),
        Case("ERROR: [generic] Unable to download webpage: HTTP Error 404: Not Found", "Video unavailable", .nothing),
        Case("ERROR: Unsupported URL: https://example.com/page", "Site not supported", .browserCapture),
        Case(
            "ERROR: [generic] Unable to download webpage: <urlopen error [Errno 8] nodename nor servname "
                + "provided, or not known>",
            "Network problem",
            .retry,
        ),
        Case(
            "ERROR: [youtube] abc: Unable to download API page: <urlopen error [Errno 60] Operation timed out>",
            "Network problem",
            .retry,
        ),
        Case(
            "ERROR: [generic] Unable to download webpage: <urlopen error [Errno 51] Network is unreachable>",
            "Network problem",
            .retry,
        ),
        Case(
            "ERROR: [generic] Unable to download webpage: <urlopen error Temporary failure in name resolution>",
            "Network problem",
            .retry,
        ),
        Case(
            "ERROR: [twitter] 1: Unable to download JSON metadata: HTTP Error 429: Too Many Requests",
            "Network problem",
            .retry,
        ),
        Case(
            "ERROR: [generic] Unable to download webpage: HTTP Error 503: Service Unavailable",
            "Network problem",
            .retry,
        ),
        Case("ERROR: unable to download video data: HTTP Error 403: Forbidden", "Download failed", .retry),
        Case("", "Download failed", .retry),
    ]

    @Test(arguments: cases)
    func `an error line maps to a reason and one action`(testCase: Case) {
        let reason = FailureReason(testCase.line)
        #expect(reason.text == testCase.text)
        #expect(reason.action == testCase.action)
    }

    @Test
    func `only a failed item has a reason`() throws {
        var item = try DownloadItem(url: #require(URL(string: "https://example.com/v")))
        item.errorMessage = "Unsupported URL"
        #expect(item.failureReason == nil)
        item.status = .failed
        #expect(item.failureReason?.action == .browserCapture)
    }
}
