@testable import Danny
import Foundation
import Testing

/// The Mac stays awake while a download runs, and only then: nothing is held at
/// idle (ADR-008), and the hold ends the moment the last run does.
@MainActor
struct KeepAwakeTests {
    /// Stands in for the power assertion and remembers every change to it.
    final class FakeKeepAwake: KeepAwake {
        private(set) var changes: [Bool] = []
        var isHeld = false {
            didSet { changes.append(isHeld) }
        }
    }

    private let scratch = TestScratch()
    private let awake = FakeKeepAwake()

    private func manager(
        probeDelay: Duration = .zero, engineInstalled: Bool = true,
    ) -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        let ytdlp = URL(fileURLWithPath: engineInstalled ? "/bin/sh" : "/nonexistent/yt-dlp")
        return DownloadManager(
            settings: settings, client: ExistingFileTests.FakeEngine(probeDelay: probeDelay),
            binaries: YTDLPClient.Binaries(ytdlp: ytdlp, ffmpegDirectory: nil), persists: false, keepAwake: awake,
        )
    }

    private func add(_ manager: DownloadManager) throws {
        try manager.add(url: #require(URL(string: "https://example.com/watch?v=abc")))
    }

    private func settle(_ manager: DownloadManager, until status: ItemStatus) async throws {
        for _ in 0 ..< 200 where manager.items.first?.status != status {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == status)
    }

    @Test func `holds nothing at idle`() {
        _ = manager()
        #expect(awake.changes.isEmpty)
        #expect(!awake.isHeld)
    }

    @Test func `holds while a download runs and lets go when it finishes`() async throws {
        let manager = manager(probeDelay: .milliseconds(200))
        try add(manager)
        #expect(awake.isHeld)
        try await settle(manager, until: .finished)
        #expect(!awake.isHeld)
        #expect(awake.changes == [true, false])
    }

    @Test func `lets go when a download fails`() async throws {
        let manager = manager(engineInstalled: false)
        try add(manager)
        try await settle(manager, until: .failed)
        #expect(!awake.isHeld)
        #expect(awake.changes == [true, false])
    }

    @Test func `lets go the moment a download is cancelled`() throws {
        let manager = manager(probeDelay: .seconds(30))
        try add(manager)
        #expect(awake.isHeld)
        let id = try #require(manager.items.first?.id)
        manager.cancel(id: id)
        #expect(!awake.isHeld)
    }
}
