@testable import Danny
import Foundation
import Testing

struct YTDLPUpdaterTests {
    private let binary = Data("#!/bin/sh\necho 2026.09.01\n".utf8)

    /// A fake GitHub: the latest release, its checksums and its binary.
    private func updater(
        latest: String = "2026.09.01", checksum: String? = nil, runs: Bool = true, fetched: Recorder = Recorder(),
    ) -> (YTDLPUpdater, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let binary = binary
        let sum = checksum ?? YTDLPUpdater.sha256(binary)
        var updater = YTDLPUpdater()
        updater.directory = directory
        updater.fetch = { url in
            await fetched.add(url)
            switch url.lastPathComponent {
            case "latest": return Data(#"{"tag_name": "\#(latest)"}"#.utf8)
            case "SHA2-256SUMS": return Data("\(sum)  yt-dlp_macos\nabc  yt-dlp.exe\n".utf8)
            case "yt-dlp_macos": return binary
            default: throw URLError(.fileDoesNotExist)
            }
        }
        updater.versionOf = { _ in runs ? latest : nil }
        return (updater, directory)
    }

    actor Recorder {
        var urls: [URL] = []
        func add(_ url: URL) { urls.append(url) }
    }

    @Test
    func `a newer release is verified and installed as an executable`() async throws {
        let (updater, directory) = updater()
        #expect(await updater.update(from: "2026.08.19") == .updated("2026.09.01"))
        let installed = directory.appendingPathComponent("yt-dlp")
        #expect(try Data(contentsOf: installed) == binary)
        #expect(FileManager.default.isExecutableFile(atPath: installed.path))
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path) == ["yt-dlp"])
    }

    @Test
    func `the current version downloads nothing`() async {
        let fetched = Recorder()
        let (updater, _) = updater(fetched: fetched)
        #expect(await updater.update(from: "2026.09.01") == .current("2026.09.01"))
        #expect(await fetched.urls.map(\.lastPathComponent) == ["latest"])
    }

    @Test
    func `a checksum mismatch installs nothing`() async {
        let (updater, directory) = updater(checksum: String(repeating: "0", count: 64))
        guard case .failed = await updater.update(from: "2026.08.19") else {
            Issue.record("expected a failure")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("yt-dlp").path))
    }

    @Test
    func `a binary that doesn't run installs nothing`() async throws {
        let (updater, directory) = updater(runs: false)
        guard case .failed = await updater.update(from: nil) else {
            Issue.record("expected a failure")
            return
        }
        #expect(try FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty)
    }

    @Test
    func `versions compare as dates with an optional build number`() {
        #expect(YTDLPUpdater.isNewer("2026.09.01", than: "2026.08.19"))
        #expect(YTDLPUpdater.isNewer("2026.08.19.1", than: "2026.08.19"))
        #expect(!YTDLPUpdater.isNewer("2026.08.19", than: "2026.08.19"))
        #expect(!YTDLPUpdater.isNewer("2025.12.31", than: "2026.01.01"))
    }

    @Test
    func `checksums are read from a sha256sum list`() {
        let sums = "AAA  yt-dlp\nbbb  yt-dlp_macos\nccc *yt-dlp_linux\n"
        #expect(YTDLPUpdater.checksum(of: "yt-dlp_macos", in: sums) == "bbb")
        #expect(YTDLPUpdater.checksum(of: "yt-dlp_linux", in: sums) == "ccc")
        #expect(YTDLPUpdater.checksum(of: "yt-dlp_macos_legacy", in: sums) == nil)
    }
}
