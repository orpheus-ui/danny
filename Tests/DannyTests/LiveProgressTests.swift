@testable import Danny
import Foundation
import Observation
import Synchronization
import Testing

/// A progress line changes its own card's `LiveProgress`, at most twice a second, and
/// never the list; the item takes the last line when the run ends. The list itself is
/// stored and worked out again when what it depends on changes.
@MainActor
struct LiveProgressTests {
    /// Stands in for yt-dlp: the test sends the download's lines.
    final class ScriptedEngine: DownloadEngine {
        let lines = Mutex<AsyncThrowingStream<DownloadEvent, Error>.Continuation?>(nil)

        @concurrent
        func probe(url _: URL, binaries _: YTDLPClient.Binaries, extraArguments _: [String]) async throws
            -> VideoMetadata
        {
            try JSONDecoder().decode(VideoMetadata.self, from: Data(#"{"id":"abc","title":"Clip"}"#.utf8))
        }

        @concurrent
        func version(binaries _: YTDLPClient.Binaries) async -> String? { nil }

        func downloadStream(
            url _: URL, into _: URL, binaries _: YTDLPClient.Binaries, extraArguments _: [String],
        ) -> AsyncThrowingStream<DownloadEvent, Error> {
            AsyncThrowingStream { continuation in lines.withLock { $0 = continuation } }
        }

        /// Sends `count` lines, the last one at the full size.
        func send(_ count: Int, of total: Int64 = 100) {
            lines.withLock { continuation in
                for line in 1 ... count {
                    continuation?.yield(.progress(
                        downloaded: total * Int64(line) / Int64(count), total: total, speedBytesPerSecond: Double(line),
                    ))
                }
            }
        }

        func end(throwing error: Error? = nil) {
            lines.withLock { $0?.finish(throwing: error) }
        }
    }

    struct Broken: Error {}

    final class Flag: Sendable {
        let raised = Mutex(false)
    }

    private let scratch = TestScratch()
    private let engine = ScriptedEngine()

    private func manager(network: any NetworkPath = NetworkTests.FakeNetworkPath(isMetered: false)) -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        settings.downloadsOnlyOnWiFi = true
        return DownloadManager(
            settings: settings, client: engine,
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil),
            persists: false, keepAwake: KeepAwakeTests.FakeKeepAwake(), network: network,
        )
    }

    /// Adds a link and waits until its run listens for lines.
    private func downloading(_ manager: DownloadManager) async throws -> UUID {
        try manager.add(url: #require(URL(string: "https://example.com/watch?v=abc")))
        let id = try #require(manager.items.first?.id)
        for _ in 0 ..< 200 where manager.liveProgress[id] == nil || engine.lines.withLock({ $0 == nil }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == .downloading)
        return id
    }

    private func settle(_ manager: DownloadManager, until status: ItemStatus) async throws {
        for _ in 0 ..< 200 where manager.items.first?.status != status {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == status)
    }

    @Test func `progress lines change the card's live progress, throttled, and not the list`() async throws {
        let manager = manager()
        let id = try await downloading(manager)
        let listChanged = Flag()
        withObservationTracking {
            _ = manager.items
            _ = manager.visibleGroups
        } onChange: {
            listChanged.raised.withLock { $0 = true }
        }

        engine.send(50)
        try await Task.sleep(for: .milliseconds(100))

        #expect(!listChanged.raised.withLock { $0 })
        // The first line shows at once; the 49 after it, well within half a second, wait.
        #expect(manager.liveProgress[id]?.line == LiveProgress.Line(fraction: 0.02, totalBytes: 100, speed: 1))
        #expect(manager.withProgress(manager.items[0]).fractionCompleted == 0.02)
        #expect(manager.items[0].fractionCompleted == nil)
    }

    @Test func `a run that ends hands its last line to the item`() async throws {
        let manager = manager()
        let id = try await downloading(manager)

        engine.send(50)
        engine.end(throwing: Broken())
        try await settle(manager, until: .failed)

        // The last line was throttled away from the card, but not from the item.
        #expect(manager.liveProgress[id] == nil)
        #expect(manager.items[0].fractionCompleted == DownloadProgress.ceiling)
        #expect(manager.items[0].totalBytes == 100)
    }

    @Test func `the list follows the items, the filter and the sort order`() throws {
        // On a metered path nothing starts, so the cards stay as added.
        let manager = manager(network: NetworkTests.FakeNetworkPath(isMetered: true))
        for host in ["a", "b", "c"] {
            try manager.add(url: #require(URL(string: "https://\(host).example.com/v")))
        }
        let ids = manager.items.map(\.id) // newest first: c, b, a
        #expect(manager.visibleItems.map(\.id) == ids)
        #expect(manager.visibleGroups.map(\.section) == [.active])

        manager.sortOrder = .oldest
        #expect(manager.visibleItems.map(\.id) == ids.reversed())

        manager.filter.text = "b.example"
        #expect(manager.visibleItems.map(\.id) == [ids[1]])

        manager.filter = DownloadFilter()
        manager.remove(id: ids[1])
        #expect(manager.visibleItems.map(\.id) == [ids[2], ids[0]])
    }

    @Test func `the list regroups when the day changes`() throws {
        let manager = manager(network: NetworkTests.FakeNetworkPath(isMetered: true))
        try manager.add(url: #require(URL(string: "https://example.com/v")))
        let id = try #require(manager.items.first?.id)
        manager.cancel(id: id)
        #expect(manager.visibleGroups.map(\.section) == [.today])

        manager.today = .now.addingTimeInterval(2 * 86400)
        #expect(manager.visibleGroups.map(\.section) == [.earlier])
    }
}
