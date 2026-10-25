@testable import Danny
import Foundation
import Testing

/// Open, Quick Look and the hover actions act on a finished item's file, and only on that.
struct FinishedItemTests {
    private func item(_ status: ItemStatus, file: String? = "/tmp/video.mp4") -> DownloadItem {
        var item = DownloadItem(url: URL(string: "https://vimeo.com/1")!)
        item.status = status
        item.filePath = file
        return item
    }

    @Test func `a finished item with a file has a file URL`() {
        #expect(item(.finished).fileURL == URL(fileURLWithPath: "/tmp/video.mp4"))
    }

    @Test(arguments: [ItemStatus.queued, .resolving, .choosing, .existing, .downloading, .processing, .paused, .failed])
    func `an unfinished item has no file URL, even with a path`(status: ItemStatus) {
        #expect(item(status).fileURL == nil)
    }

    @Test func `a finished item without a path has no file URL`() {
        #expect(item(.finished, file: nil).fileURL == nil)
    }
}
