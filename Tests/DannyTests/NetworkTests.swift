@testable import Danny
import Foundation
import Observation
import Synchronization
import Testing

/// "Download only on Wi-Fi" holds queued items on a metered path and starts them when
/// the path changes; the speed limit reaches yt-dlp as `--limit-rate`.
@MainActor
struct NetworkTests {
    @Observable
    final class FakeNetworkPath: NetworkPath {
        var isMetered: Bool
        init(isMetered: Bool) { self.isMetered = isMetered }
    }

    /// Records each download's extra arguments.
    final class RecordingEngine: DownloadEngine {
        let arguments = Mutex<[[String]]>([])

        @concurrent
        func probe(url _: URL, binaries _: YTDLPClient.Binaries, extraArguments _: [String]) async throws
            -> VideoMetadata
        {
            try JSONDecoder().decode(VideoMetadata.self, from: Data(#"{"id":"abc","title":"Clip"}"#.utf8))
        }

        @concurrent
        func version(binaries _: YTDLPClient.Binaries) async -> String? { nil }

        func downloadStream(
            url _: URL, into directory: URL, binaries _: YTDLPClient.Binaries, extraArguments: [String],
        ) -> AsyncThrowingStream<DownloadEvent, Error> {
            arguments.withLock { $0.append(extraArguments) }
            let path = directory.appendingPathComponent("Clip [abc].mp4").path
            return AsyncThrowingStream { continuation in
                continuation.yield(.outputFile(path))
                continuation.finish()
            }
        }
    }

    private let scratch = TestScratch()

    private func manager(
        path: FakeNetworkPath, engine: RecordingEngine = RecordingEngine(), configure: (AppSettings) -> Void,
    ) -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        configure(settings)
        return DownloadManager(
            settings: settings, client: engine,
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil),
            persists: false, keepAwake: KeepAwakeTests.FakeKeepAwake(), network: path,
        )
    }

    private func add(_ manager: DownloadManager) throws {
        try manager.add(url: #require(URL(string: "https://www.example.com/watch?v=abc")))
    }

    private func settle(_ manager: DownloadManager, until status: ItemStatus) async throws {
        for _ in 0 ..< 200 where manager.items.first?.status != status {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == status)
    }

    @Test(arguments: [(false, false, true), (false, true, true), (true, false, true), (true, true, false)])
    func `starts unless Wi-Fi only and metered`(wifiOnly: Bool, metered: Bool, starts: Bool) throws {
        let manager = manager(path: FakeNetworkPath(isMetered: metered)) { $0.downloadsOnlyOnWiFi = wifiOnly }
        try add(manager)
        #expect(manager.waitsForWiFi == !starts)
        #expect((manager.items.first?.status != .queued) == starts)
    }

    @Test func `a waiting item starts when the path stops being metered`() async throws {
        let path = FakeNetworkPath(isMetered: true)
        let manager = manager(path: path) { $0.downloadsOnlyOnWiFi = true }
        try add(manager)
        #expect(manager.items.first?.status == .queued)
        path.isMetered = false
        try await settle(manager, until: .finished)
    }

    @Test func `a waiting item starts when the setting is turned off`() async throws {
        let manager = manager(path: FakeNetworkPath(isMetered: true)) { $0.downloadsOnlyOnWiFi = true }
        try add(manager)
        manager.settings.downloadsOnlyOnWiFi = false
        try await settle(manager, until: .finished)
    }

    @Test func `hotspot, then offline, then Wi-Fi`() {
        let hotspot = SystemNetworkPath.isMetered(satisfied: true, expensive: true, cellular: false)
        let offline = SystemNetworkPath.isMetered(satisfied: false, expensive: false, cellular: false)
        let wifi = SystemNetworkPath.isMetered(satisfied: true, expensive: false, cellular: false)
        #expect([hotspot, offline, wifi] == [true, true, false])
        #expect(SystemNetworkPath.isMetered(satisfied: true, expensive: false, cellular: true))
    }

    @Test func `limit rate arguments`() {
        #expect(YTDLPClient.limitRateArguments(0) == [])
        #expect(YTDLPClient.limitRateArguments(500_000) == ["--limit-rate", "500000"])
    }

    @Test func `the speed limit reaches the download`() async throws {
        let engine = RecordingEngine()
        let manager = manager(path: FakeNetworkPath(isMetered: false), engine: engine) {
            $0.speedMode = .background
        }
        try add(manager)
        try await settle(manager, until: .finished)
        let recorded = engine.arguments.withLock { $0 }
        let arguments = try #require(recorded.first)
        #expect(arguments.suffix(2) == ["--limit-rate", "1000000"])
    }
}
