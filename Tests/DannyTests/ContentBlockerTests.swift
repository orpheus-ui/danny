@testable import Danny
import Foundation
import Testing
import WebKit

@MainActor
struct ContentBlockerTests {
    private let scratch = TestScratch()

    @Test(arguments: [
        "https://pubads.g.doubleclick.net/gampad/ads?iu=/1/video",
        "https://s0.2mdn.net/videoplayback/preroll.mp4",
        "https://IMASDK.googleapis.com/js/sdkloader/ima3.js",
        "https://example.fwmrm.net/ad/l/1?x=1",
    ])
    func `ad hosts match the host and its subdomains`(url: String) throws {
        #expect(try AdHosts.contains(#require(URL(string: url))))
    }

    @Test(arguments: [
        "https://notdoubleclick.net/video.mp4",
        "https://cdn.example.com/doubleclick.net/video.mp4",
        "https://rr3---sn-abc.googlevideo.com/videoplayback?itag=22",
        "https://www.googleapis.com/youtube/v3/videos",
    ])
    func `other hosts do not match`(url: String) throws {
        #expect(try !AdHosts.contains(#require(URL(string: url))))
    }

    @Test
    func `captures leave ad media out`() {
        let store = SnifferStore()
        store.capture(rawURL: "https://s0.2mdn.net/ads/preroll.mp4")
        store.capture(rawURL: "https://ad.doubleclick.net/vast/master.m3u8")
        store.capture(rawURL: "https://video.example.com/movie/master.m3u8")
        #expect(store.captured.map(\.url.host) == ["video.example.com"])
    }

    @Test
    func `the rules compile in WebKit`() async throws {
        let folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let store = try #require(WKContentRuleListStore(url: folder))
        let list = await ContentBlocker.ruleList(in: store)
        #expect(list?.identifier == ContentBlocker.identifier)
    }

    @Test
    func `blocking is on by default and allowed sites stay`() {
        let defaults = scratch.defaults()
        let settings = AppSettings(defaults: defaults)
        #expect(settings.blocksAds(on: "news.example.com"))

        settings.adsAllowedSites.insert("news.example.com")
        let reopened = AppSettings(defaults: defaults)
        #expect(!reopened.blocksAds(on: "News.Example.com"))
        #expect(reopened.blocksAds(on: "other.example.com"))

        reopened.blocksAds = false
        #expect(!AppSettings(defaults: defaults).blocksAds(on: "other.example.com"))
    }
}
