@testable import Danny
import Foundation
import Testing

/// Settings' Check Now fetches yt-dlp on demand; the launch check follows the setting.
@MainActor
struct EngineCheckTests {
    private let scratch = TestScratch()

    private func manager(keepsCurrent: Bool) -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.keepsEngineCurrent = keepsCurrent
        let binaries = YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil)
        return DownloadManager(
            settings: settings, client: ExistingFileTests.FakeEngine(), binaries: binaries, persists: false,
        )
    }

    /// A fake GitHub whose latest release is 2026.09.01, installing into a scratch folder.
    private func updater() -> YTDLPUpdater {
        let binary = Data("#!/bin/sh\necho 2026.09.01\n".utf8)
        var updater = YTDLPUpdater()
        updater.directory = scratch.folder()
        updater.fetch = { url in
            switch url.lastPathComponent {
            case "latest": return Data(#"{"tag_name": "2026.09.01"}"#.utf8)
            case "SHA2-256SUMS": return Data("\(YTDLPUpdater.sha256(binary))  yt-dlp_macos\n".utf8)
            case "yt-dlp_macos": return binary
            default: throw URLError(.fileDoesNotExist)
            }
        }
        updater.versionOf = { _ in "2026.09.01" }
        return updater
    }

    @Test func `check now runs even when automatic updates are off`() async {
        let manager = manager(keepsCurrent: false)
        await manager.checkEngine(with: updater(), manual: true)
        #expect(manager.engineCheck?.outcome == .updated("2026.09.01"))
        #expect(manager.isCheckingEngine == false)
    }

    @Test func `the launch check waits for the setting`() async {
        let manager = manager(keepsCurrent: false)
        await manager.checkEngine(with: updater())
        #expect(manager.engineCheck == nil)
    }
}
