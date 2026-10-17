@testable import Danny
import Foundation
import Testing

/// Overall progress for the Dock, its once-a-second throttle, and the service that
/// reacts to the queue: nothing at idle (ADR-008), a notification per finished run.
@MainActor
struct SystemStatusTests {
    private func item(_ status: ItemStatus, _ fraction: Double? = nil, bytes: Int64? = nil) -> DownloadItem {
        var item = DownloadItem(url: URL(fileURLWithPath: "/clip"))
        item.status = status
        item.fractionCompleted = fraction
        item.totalBytes = bytes
        return item
    }

    // MARK: Overall progress

    @Test func `nothing running shows nothing`() {
        #expect(OverallProgress.of([]) == nil)
        #expect(OverallProgress.of([item(.finished, 1), item(.failed, 0.3)]) == nil)
        #expect(OverallProgress.of([item(.queued), item(.choosing), item(.existing)]) == nil)
    }

    @Test func `weighs by bytes when every size is known`() {
        let progress = OverallProgress.of([item(.downloading, 0.5, bytes: 300), item(.downloading, 0.9, bytes: 100)])
        #expect(progress?.fraction == 0.6)
        #expect(progress?.count == 2)
    }

    @Test func `weighs items the same when a size is unknown`() {
        let progress = OverallProgress.of([item(.downloading, 0.5, bytes: 300), item(.downloading, 0.9)])
        #expect(progress?.fraction == 0.7)
    }

    @Test func `ignores finished, failed and waiting cards, counts queued as not started`() {
        let progress = OverallProgress.of([
            item(.downloading, 0.5), item(.queued), item(.finished, 1), item(.failed, 0.2), item(.choosing),
        ])
        #expect(progress == OverallProgress(fraction: 0.25, count: 2))
    }

    @Test func `no known fraction yet is indeterminate`() {
        #expect(OverallProgress.of([item(.resolving), item(.queued)]) == OverallProgress(fraction: nil, count: 2))
    }

    // MARK: Throttle

    /// `#expect` can't call a mutating method on its argument.
    private func admit(
        _ throttle: inout DockThrottle,
        _ progress: OverallProgress?,
        at now: ContinuousClock.Instant,
    )
        -> Bool
    {
        throttle.admit(progress, at: now)
    }

    @Test func `throttle lets at most one update a second through`() {
        var throttle = DockThrottle()
        let start = ContinuousClock.now
        let half = OverallProgress(fraction: 0.5, count: 1)
        #expect(admit(&throttle, OverallProgress(fraction: 0.1, count: 1), at: start))
        #expect(!admit(&throttle, OverallProgress(fraction: 0.2, count: 1), at: start + .milliseconds(400)))
        #expect(!admit(&throttle, OverallProgress(fraction: 0.3, count: 1), at: start + .milliseconds(999)))
        #expect(admit(&throttle, half, at: start + .seconds(1)))
        #expect(!admit(&throttle, half, at: start + .seconds(5)))
    }

    @Test func `throttle clears at once and stays quiet while idle`() {
        var throttle = DockThrottle()
        let start = ContinuousClock.now
        #expect(!admit(&throttle, nil, at: start))
        #expect(admit(&throttle, OverallProgress(fraction: nil, count: 1), at: start))
        #expect(admit(&throttle, nil, at: start + .milliseconds(10)))
        #expect(!admit(&throttle, nil, at: start + .seconds(3)))
        #expect(throttle.shown == nil)
    }

    // MARK: Service

    final class FakeDock: DockProgress {
        private(set) var shown: [OverallProgress?] = []
        func show(_ progress: OverallProgress?) { shown.append(progress) }
    }

    final class FakeNotifier: FinishNotifier {
        private(set) var finished: [DownloadItem] = []
        func notifyFinished(_ item: DownloadItem) { finished.append(item) }
    }

    private let scratch = TestScratch()
    private let dock = FakeDock()
    private let notifier = FakeNotifier()

    private func manager() -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        return DownloadManager(
            settings: settings, client: ExistingFileTests.FakeEngine(probeDelay: .milliseconds(100)),
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil),
            persists: false, keepAwake: KeepAwakeTests.FakeKeepAwake(),
        )
    }

    @Test func `does nothing at idle`() async throws {
        let status = SystemStatus(manager: manager(), dock: dock, notifier: notifier)
        try await Task.sleep(for: .milliseconds(50))
        #expect(dock.shown.isEmpty)
        #expect(notifier.finished.isEmpty)
        _ = status
    }

    @Test func `shows progress while downloading, then clears and notifies`() async throws {
        let manager = manager()
        let menuBar = MenuBarState()
        let status = SystemStatus(manager: manager, dock: dock, notifier: notifier, menuBar: menuBar)
        try manager.add(url: #require(URL(string: "https://example.com/watch?v=abc")))
        for _ in 0 ..< 200 where manager.items.first?.status != .finished || dock.shown.last != .some(nil) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == .finished)
        #expect(dock.shown.first??.count == 1)
        #expect(dock.shown.last == .some(nil))
        #expect(notifier.finished.map(\.id) == manager.items.map(\.id))
        #expect(notifier.finished.first?.filePath != nil)
        #expect(menuBar.icon == nil)
        _ = status
    }
}
