@testable import Danny
import Foundation
import Testing

/// The list shows active items first, then the day's finished ones, then older ones.
@MainActor
struct ItemGroupingTests {
    /// 08:00 UTC, so up to eight hours ago is still today.
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private func item(_ status: ItemStatus, hoursAgo: Double = 0) -> DownloadItem {
        var item = DownloadItem(url: URL(string: "https://vimeo.com/\(UUID().uuidString)")!)
        item.status = status
        item.addedAt = now.addingTimeInterval(-hoursAgo * 3600)
        return item
    }

    private func grouped(_ items: [DownloadItem]) -> [ItemGroup] {
        DownloadManager.grouped(items, now: now, calendar: calendar)
    }

    @Test(arguments: [ItemStatus.queued, .resolving, .choosing, .existing, .downloading, .processing, .paused])
    func `an unfinished item is active, however old`(status: ItemStatus) {
        #expect(grouped([item(status, hoursAgo: 100)]).map(\.section) == [.active])
    }

    @Test func `finished and failed items split by the day they were added`() {
        let groups = grouped([item(.finished), item(.failed, hoursAgo: 2), item(.finished, hoursAgo: 30)])
        #expect(groups.map(\.section) == [.today, .earlier])
        #expect(groups.map(\.items.count) == [2, 1])
    }

    @Test func `sections come in a fixed order, not the order of the input`() {
        let groups = grouped([item(.finished, hoursAgo: 48), item(.finished), item(.downloading)])
        #expect(groups.map(\.section) == [.active, .today, .earlier])
    }

    @Test func `items keep their order inside a section`() {
        let first = item(.finished, hoursAgo: 3)
        let second = item(.finished, hoursAgo: 1)
        let third = item(.finished, hoursAgo: 2)
        #expect(grouped([first, second, third]).first?.items.map(\.id) == [first.id, second.id, third.id])
    }

    @Test func `empty sections are left out`() {
        #expect(grouped([]).isEmpty)
        #expect(grouped([item(.finished)]).map(\.section) == [.today])
    }

    @Test func `quick Look finds the selected item in any section`() {
        var done = item(.finished, hoursAgo: 48)
        done.filePath = "/tmp/video.mp4"
        let groups = grouped([item(.downloading), done])
        #expect(groups.flatMap(\.items).previewURL(selection: done.id) == done.fileURL)
    }
}
