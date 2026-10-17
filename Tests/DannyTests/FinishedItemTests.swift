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

    @Test(arguments: [ItemStatus.queued, .resolving, .choosing, .existing, .downloading, .processing, .failed])
    func `an unfinished item has no file URL, even with a path`(status: ItemStatus) {
        #expect(item(status).fileURL == nil)
    }

    @Test func `a finished item without a path has no file URL`() {
        #expect(item(.finished, file: nil).fileURL == nil)
    }

    @Test func `space previews the selected finished item`() {
        let finished = item(.finished)
        let other = item(.finished, file: "/tmp/other.mp4")
        #expect([other, finished].previewURL(selection: finished.id) == finished.fileURL)
    }

    @Test func `space previews nothing for no selection, an unfinished one or an unlisted one`() {
        let finished = item(.finished)
        let failed = item(.failed)
        #expect([finished].previewURL(selection: nil) == nil)
        #expect([finished, failed].previewURL(selection: failed.id) == nil)
        #expect([failed].previewURL(selection: finished.id) == nil)
    }
}
