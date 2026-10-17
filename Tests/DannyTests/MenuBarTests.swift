import AppKit
@testable import Danny
import Foundation
import Testing

/// The menu-bar item: which items it lists, the state the Dock throttle feeds it, the
/// ring, and the setting that turns it on (off by default).
@MainActor
struct MenuBarTests {
    private func item(_ status: ItemStatus, _ title: String = "Clip", fraction: Double? = nil) -> DownloadItem {
        var item = DownloadItem(url: URL(fileURLWithPath: "/clip"))
        item.title = title
        item.status = status
        item.fractionCompleted = fraction
        return item
    }

    private let epoch = Date(timeIntervalSince1970: 1_800_000_000)

    private func list(_ items: [DownloadItem]) -> MenuBarList {
        MenuBarList(items: items, finishedAt: { $0.addedAt })
    }

    @Test func `lists running and queued items, moving ones first`() {
        let list = list([
            item(.queued, "C"), item(.finished, "F"), item(.downloading, "A", fraction: 0.4), item(.failed, "X"),
            item(.choosing, "W"), item(.processing, "B"),
        ])
        #expect(list.active.map(\.title) == ["A", "B", "C"])
        #expect(list.active.first?.fraction == 0.4)
        #expect(list.more == 0)
    }

    @Test func `caps the list at four and counts the rest`() {
        let list = list((0 ..< 7).map { _ in item(.downloading) })
        #expect(list.active.count == MenuBarList.maxActive)
        #expect(list.more == 3)
        #expect(list.headline == "7 downloading")
    }

    @Test func `headline gives the count and the combined speed, or says nothing runs`() {
        var first = item(.downloading, fraction: 0.2)
        first.speedBytesPerSecond = 2_000_000
        var second = item(.downloading, fraction: 0.6)
        second.speedBytesPerSecond = 3_000_000
        #expect(list([first, second]).headline == "2 downloading · 5 MBps")
        #expect(list([item(.queued), item(.queued)]).headline == "2 waiting")
        #expect(list([item(.paused), item(.paused)]).headline == "2 paused")
        #expect(list([item(.paused), item(.paused)]).active.isEmpty)
        #expect(list([item(.finished)]).headline == "Nothing downloading")
        #expect(list([]).headline == "Nothing downloading")
    }

    @Test func `a row says progress, speed and time left, and what it can't leaves out`() {
        var running = item(.downloading, fraction: 0.59)
        running.totalBytes = 100_000_000
        running.downloadedBytes = 59_000_000
        running.speedBytesPerSecond = 2_000_000
        let row = list([running]).active[0]
        #expect(row.detail == "59% · 2 MBps · 21 s left")
        #expect(row.spokenLabel == "Clip, 59 percent, 2 megabytes per second")
        #expect(list([item(.resolving)]).active[0].detail == "")
        #expect(Format.remaining(150) == "3 min left")
        #expect(Format.remaining(7200) == "2 h left")
    }

    @Test func `recently finished are the last three that have a file, newest first`() {
        func done(_ title: String, minutesAgo: Double, file: String? = "/f") -> DownloadItem {
            var done = item(.finished, title)
            done.filePath = file
            done.addedAt = epoch.addingTimeInterval(-minutesAgo * 60)
            return done
        }
        let list = list([
            done("old", minutesAgo: 90), done("a", minutesAgo: 1), done("gone", minutesAgo: 0, file: nil),
            done("b", minutesAgo: 5), done("c", minutesAgo: 30),
        ])
        #expect(list.finished.map(\.title) == ["a", "b", "c"])
    }

    @Test func `age reads as just now, minutes, hours or days`() {
        func age(_ seconds: Double) -> String { MenuBarList.age(of: epoch.addingTimeInterval(-seconds), now: epoch) }
        #expect(age(5) == "Just now")
        #expect(age(120) == "2 min ago")
        #expect(age(3 * 3600) == "3 h ago")
        #expect(age(2 * 86400) == "2 d ago")
        #expect(MenuBarList.age(of: epoch.addingTimeInterval(60), now: epoch) == "Just now")
    }

    @Test func `the popover offers the clipboard's link, and nothing when there isn't one`() {
        let scratch = TestScratch()
        let settings = AppSettings(defaults: scratch.defaults())
        let manager = DownloadManager(
            settings: settings, client: ExistingFileTests.FakeEngine(probeDelay: .milliseconds(100)),
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil),
            persists: false, keepAwake: KeepAwakeTests.FakeKeepAwake(),
        )
        let board = NSPasteboard(name: NSPasteboard.Name("danny.menubar.tests.\(UUID().uuidString)"))
        #expect(MenuBarPopoverModel(manager: manager, pasteboard: board).clipboardLink == nil)
        board.clearContents()
        board.setString("watch this https://example.com/watch?v=1 now", forType: .string)
        #expect(MenuBarPopoverModel(manager: manager, pasteboard: board).clipboardLink?.host() == "example.com")
        board.clearContents()
        board.setString("no link here", forType: .string)
        #expect(MenuBarPopoverModel(manager: manager, pasteboard: board).clipboardLink == nil)
    }

    @Test func `a site's icon is fetched once and shared with its www twin`() async throws {
        final class Counter { var urls: [URL] = [] }
        let counter = Counter()
        let png = NSImage(size: NSSize(width: 4, height: 4), flipped: false) { _ in true }
            .tiffRepresentation
        let folder = TestScratch().folder()
        let cache = Favicons(folder: folder) { url in
            counter.urls.append(url)
            return url.host() == "example.com" ? png : nil
        }
        #expect(await cache.image(for: "example.com") != nil)
        #expect(await cache.image(for: "www.Example.com") != nil)
        #expect(try counter.urls == [#require(URL(string: "https://example.com/favicon.ico"))])
        // A new cache (a new launch) reads the saved file without fetching.
        let again = Favicons(folder: folder) { _ in nil }
        #expect(await again.image(for: "example.com") != nil)
        #expect(await cache.image(for: "other.org") == nil)
        #expect(Favicons.key(for: "WWW.YouTube.com") == "youtube.com")
    }

    @Test func `state follows what it is given and empties when idle`() {
        let state = MenuBarState()
        #expect(state.icon == nil)
        state.show(OverallProgress(fraction: 0.5, count: 1))
        #expect(state.icon == MenuBarIcon(OverallProgress(fraction: 0.5, count: 1)))
        state.show(nil)
        #expect(state.icon == nil)
    }

    @Test func `icon shows the whole percent, nothing before a size is known`() {
        #expect(MenuBarIcon(OverallProgress(fraction: 0.428, count: 1)).percent == 42)
        #expect(MenuBarIcon(OverallProgress(fraction: 1, count: 1)).percent == 100)
        #expect(MenuBarIcon(OverallProgress(fraction: nil, count: 1)).percent == nil)
    }

    @Test func `the icon changes only with the whole percent`() {
        let state = MenuBarState()
        state.show(OverallProgress(fraction: 0.421, count: 1))
        let before = state.icon
        state.show(OverallProgress(fraction: 0.425, count: 1))
        #expect(state.icon == before)
        #expect(state.icon?.percent == 42)
    }

    @Test(arguments: [(0, 0.0), (50, 9.0), (100, 18.0), (150, 18.0)])
    func `fill covers the bottom of the mark`(percent: Int, height: Double) {
        let bounds = CGRect(x: 0, y: 0, width: 18, height: 18)
        let fill = MenuBarIcon.fillRect(percent: percent, in: bounds)
        #expect(fill == CGRect(x: 0, y: 0, width: 18, height: height))
        #expect(MenuBarIcon.fillRect(percent: nil, in: bounds).isEmpty)
    }

    @Test(arguments: [
        (true, false, MenuBarStyle.Fill.brandLight), (false, false, .brandDeep),
        (true, true, .label), (false, true, .label),
    ])
    func `the fill is purple, lighter on a dark bar, and the label colour while the menu is open`(
        isDark: Bool, menuOpen: Bool, fill: MenuBarStyle.Fill,
    ) {
        #expect(MenuBarStyle(isDark: isDark, menuOpen: menuOpen).fill == fill)
        #expect(MenuBarMark.fillColor(fill) == nil || fill != .label)
        #expect(MenuBarStyle.baseAlpha == 0.5)
    }

    @Test func `idle is a template image, downloading is coloured and leaves room for the percentage`() {
        let idle = MenuBarMark.image(nil)
        #expect(idle.isTemplate)
        #expect(idle.accessibilityDescription == "Danny")
        let half = MenuBarMark.image(MenuBarIcon(OverallProgress(fraction: 0.5, count: 1)))
        #expect(!half.isTemplate)
        #expect(half.size.width == MenuBarMark.size.width + MenuBarMark.gap)
        #expect(half.accessibilityDescription == "Danny, 50 percent")
        #expect(MenuBarMark.image(MenuBarIcon(OverallProgress(fraction: nil, count: 1))).size == MenuBarMark.size)
        #expect(NSImage(named: "menu-bar-mark") != nil)
    }

    @Test func `a sample launch shows the item without the setting`() {
        #expect(MenuBarVisibility.isShown(setting: true, arguments: []))
        #expect(!MenuBarVisibility.isShown(setting: false, arguments: ["Danny"]))
        #if DEBUG
            #expect(MenuBarVisibility.isShown(setting: false, arguments: ["Danny", "-sample-queue"]))
        #endif
    }

    @Test func `the menu-bar item is off by default and remembered`() {
        let scratch = TestScratch()
        let defaults = scratch.defaults()
        let first = AppSettings(defaults: defaults)
        #expect(!first.menuBarItem)
        first.menuBarItem = true
        #expect(AppSettings(defaults: defaults).menuBarItem)
    }
}
