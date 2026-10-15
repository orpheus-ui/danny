@testable import Danny
import Foundation
import Testing

struct DownloadFilterTests {
    private func item(_ url: String, title: String = "Clip", status: ItemStatus = .finished) -> DownloadItem {
        var item = DownloadItem(url: URL(string: url)!)
        item.title = title
        item.status = status
        return item
    }

    @Test(arguments: [
        ("https://youtu.be/abc", true),
        ("  http://vimeo.com/1  ", true),
        ("youtube.com", false),
        ("cats", false),
        ("https://", false),
        ("https://a.com/x and more", false),
        ("ftp://example.com/file", false),
    ])
    func `text is a link only when it is an explicit http URL`(text: String, isLink: Bool) {
        #expect((DownloadFilter(text: text).link != nil) == isLink)
    }

    @Test
    func `text matches title, host and URL, ignoring case`() {
        let cat = item("https://www.youtube.com/watch?v=1", title: "Cat Video")
        #expect(DownloadFilter(text: "cat").matches(cat))
        #expect(DownloadFilter(text: "YOUTUBE").matches(cat))
        #expect(DownloadFilter(text: "v=1").matches(cat))
        #expect(!DownloadFilter(text: "dog").matches(cat))
    }

    @Test
    func `a link matches the same video, ignoring the fragment`() {
        let cat = item("https://vimeo.com/42")
        #expect(DownloadFilter(text: "https://vimeo.com/42#t=10").matches(cat))
        #expect(!DownloadFilter(text: "https://vimeo.com/43").matches(cat))
    }

    @Test
    func `scope and site narrow the list`() {
        let active = item("https://www.youtube.com/1", status: .downloading)
        let failed = item("https://vimeo.com/2", status: .failed)
        #expect(DownloadFilter(scope: .active).matches(active))
        #expect(!DownloadFilter(scope: .active).matches(failed))
        #expect(DownloadFilter(site: "youtube.com").matches(active))
        #expect(!DownloadFilter(site: "youtube.com").matches(failed))
    }

    @Test
    func `counts follow the text but not the scope`() {
        let items = [
            item("https://a.com/1", title: "cat", status: .downloading),
            item("https://a.com/2", title: "cat", status: .failed),
            item("https://a.com/3", title: "dog", status: .finished),
        ]
        let counts = DownloadFilter(text: "cat", scope: .failed).counts(in: items)
        #expect(counts == [.all: 2, .active: 1, .done: 0, .failed: 1])
    }

    @Test
    func `sites are ranked by count, without www`() {
        let items = [
            item("https://www.youtube.com/1"), item("https://youtube.com/2"),
            item("https://vimeo.com/3"), item("https://archive.org/4"),
        ]
        #expect(DownloadFilter.sites(in: items, limit: 2) == ["youtube.com", "archive.org"])
    }

    @Test
    func `the selected site stays a chip after it leaves the top`() {
        let items = [item("https://youtube.com/1"), item("https://youtube.com/2"), item("https://vimeo.com/3")]
        #expect(DownloadFilter.sites(in: items, limit: 1, keeping: "vimeo.com") == ["youtube.com", "vimeo.com"])
        #expect(DownloadFilter.sites(in: items, limit: 1, keeping: "youtube.com") == ["youtube.com"])
    }
}
