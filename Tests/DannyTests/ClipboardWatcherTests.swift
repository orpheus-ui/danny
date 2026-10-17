import AppKit
@testable import Danny
import Foundation
import Testing

/// A copied link is checked when Danny becomes active, never on a timer, and the
/// setting decides whether it is offered, added at once or ignored.
@MainActor
struct ClipboardWatcherTests {
    private let scratch = TestScratch()
    private let pasteboard = NSPasteboard.withUniqueName()

    private func watcher(_ policy: ClipboardPolicy) -> ClipboardWatcher {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        settings.clipboard = policy
        let manager = DownloadManager(
            settings: settings, client: ExistingFileTests.FakeEngine(),
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/nonexistent/yt-dlp"), ffmpegDirectory: nil),
            persists: false,
        )
        return ClipboardWatcher(settings: settings, manager: manager, pasteboard: pasteboard)
    }

    private func copy(_ string: String) {
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }

    @Test func `ask offers the copied link without adding it`() {
        let watcher = watcher(.ask)
        copy("https://www.youtube.com/watch?v=abc")
        watcher.check()
        #expect(watcher.offer == URL(string: "https://www.youtube.com/watch?v=abc"))
        #expect(watcher.manager.items.isEmpty)

        watcher.acceptOffer()
        #expect(watcher.offer == nil)
        #expect(watcher.manager.items.count == 1)
    }

    @Test func `dismissing the offer adds nothing`() {
        let watcher = watcher(.ask)
        copy("https://vimeo.com/1")
        watcher.check()
        watcher.dismissOffer()
        #expect(watcher.offer == nil)
        #expect(watcher.manager.items.isEmpty)
    }

    @Test func `add at once adds without offering`() {
        let watcher = watcher(.addAtOnce)
        copy("https://vimeo.com/1")
        watcher.check()
        #expect(watcher.offer == nil)
        #expect(watcher.manager.items.count == 1)
    }

    @Test func `off ignores the clipboard`() {
        let watcher = watcher(.off)
        copy("https://vimeo.com/1")
        watcher.check()
        #expect(watcher.offer == nil)
        #expect(watcher.manager.items.isEmpty)
    }

    @Test func `the same copy is offered once, and text without a link never`() {
        let watcher = watcher(.ask)
        copy("https://vimeo.com/1")
        watcher.check()
        watcher.dismissOffer()
        watcher.check()
        #expect(watcher.offer == nil)

        copy("just some words")
        watcher.check()
        #expect(watcher.offer == nil)
    }

    @Test func `what was on the clipboard at launch is not offered`() {
        copy("https://vimeo.com/1")
        let watcher = watcher(.ask)
        watcher.check()
        #expect(watcher.offer == nil)
    }

    @Test func `the toast shows the link without its scheme or www`() throws {
        let url = try #require(URL(string: "https://www.youtube.com/watch?v=abc&u=www.youtube.com"))
        #expect(ClipboardToast.shortLink(url) == "youtube.com/watch?v=abc&u=www.youtube.com")
    }
}
