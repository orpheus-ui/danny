@testable import Danny
import Foundation
import Testing

/// The bottom bar's activity pill: hidden at idle, the running count and speed while
/// anything runs, and the paused count once everything left is paused.
struct QueueActivityTests {
    private func item(_ status: ItemStatus, speed: Double? = nil) -> DownloadItem {
        var item = DownloadItem(url: URL(fileURLWithPath: "/v"))
        item.status = status
        item.speedBytesPerSecond = speed
        return item
    }

    @Test func `hidden while nothing runs or is paused`() {
        #expect(QueueActivity.of([]) == nil)
        #expect(QueueActivity.of([item(.finished), item(.failed), item(.choosing), item(.existing)]) == nil)
    }

    @Test func `counts running and queued cards and adds their speeds`() {
        let items = [
            item(.downloading, speed: 3_000_000), item(.downloading, speed: 1_100_000), item(.queued),
            item(.paused), item(.finished),
        ]
        #expect(QueueActivity.of(items) == .active(count: 3, bytesPerSecond: 4_100_000))
    }

    @Test func `no speed until a card reports one`() {
        #expect(QueueActivity.of([item(.resolving)]) == .active(count: 1, bytesPerSecond: nil))
    }

    @Test func `paused once nothing else runs`() {
        #expect(QueueActivity.of([item(.paused), item(.paused), item(.paused), item(.finished)]) == .paused(count: 3))
    }

    @Test func `reads the speed out in words`() {
        #expect(Format.spokenSpeed(4_100_000) == "4.1 megabytes per second")
        #expect(Format.spokenSpeed(512_000) == "512 kilobytes per second")
        #expect(Format.spokenSpeed(nil) == nil)
    }
}
