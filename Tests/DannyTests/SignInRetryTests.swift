@testable import Danny
import Foundation
import Testing

/// Finishing a sign-in retries the downloads that stopped to ask for it.
struct SignInRetryTests {
    private func item(_ url: String, failed message: String?) -> DownloadItem {
        var item = DownloadItem(url: URL(string: url)!)
        if let message {
            item.status = .failed
            item.errorMessage = message
        }
        return item
    }

    @Test func `picks only the sites sign in failures`() {
        let signIn = "ERROR: [youtube] abc: Sign in to confirm your age"
        let waiting = item("https://www.youtube.com/watch?v=abc", failed: signIn)
        let short = item("https://youtu.be/def", failed: signIn)
        let otherReason = item("https://www.youtube.com/watch?v=ghi", failed: "ERROR: HTTP Error 404: Not Found")
        let otherSite = item("https://www.instagram.com/p/xyz", failed: signIn)
        let queued = item("https://www.youtube.com/watch?v=jkl", failed: nil)

        let ids = DownloadManager.waitingForSignIn(
            [waiting, short, otherReason, otherSite, queued], on: .youtube,
        )
        #expect(ids == [waiting.id, short.id])
    }
}
