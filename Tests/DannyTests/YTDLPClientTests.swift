@testable import Danny
import Foundation
import Testing

struct YTDLPClientTests {
    private let scratch = TestScratch()

    /// A stand-in yt-dlp that runs `script`.
    private func fakeYTDLP(_ script: String) throws -> YTDLPClient.Binaries {
        let folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let binary = folder.appendingPathComponent("yt-dlp")
        try Data("#!/bin/sh\n\(script)\n".utf8).write(to: binary)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: binary.path)
        return .init(ytdlp: binary, ffmpegDirectory: nil)
    }

    @Test func `parses progress line`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|1048576|4194304|2.00MiB/s"))
        guard case let .progress(downloaded, total, speed, _) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(downloaded == 1_048_576)
        #expect(total == 4_194_304)
        #expect(speed == 2_097_152.0)
    }

    @Test func `unknown total is nil`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|500|NA|Unknown"))
        guard case let .progress(_, total, speed, _) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(total == nil)
        #expect(speed == nil)
    }

    @Test func `progress names the file being fetched`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|10|20|1.00KiB/s|140"))
        guard case let .progress(_, _, _, file) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(file == "140")
    }

    @Test func `the plan lists each requested file`() throws {
        let json = """
        {"id": "x", "title": "t", "requested_formats": [
            {"format_id": "616", "filesize_approx": 900},
            {"format_id": "140", "filesize": 100, "filesize_approx": 120}
        ]}
        """
        let metadata = try JSONDecoder().decode(VideoMetadata.self, from: Data(json.utf8))
        #expect(metadata.plannedFiles == ["616": 900, "140": 100])
    }

    @Test(arguments: ["[download] 5.0% of 10MiB", "@P|1|2", ""])
    func `ignores non progress lines`(line: String) {
        #expect(YTDLPClient.parseProgressLine(line) == nil)
    }

    @Test(arguments: [
        ("1.5KiB/s", 1536.0),
        ("3MiB/s", 3_145_728.0),
        ("2GiB/s", 2_147_483_648.0),
        ("800kB/s", 800_000.0),
        ("12B/s", 12.0),
    ])
    func `parses speed units`(raw: String, expected: Double) {
        #expect(YTDLPClient.parseSpeed(raw) == expected)
    }

    @Test func `rejects speed without number`() {
        #expect(YTDLPClient.parseSpeed("Unknown B/s") == nil)
    }

    /// A yt-dlp that never answers. Its output ends only when the process does, so
    /// an early answer means it was killed.
    /// A quick Pause and Resume: the second yt-dlp starts only once the first, which
    /// takes a moment to stop, has exited, so the two never write the same files.
    @Test func `a restarted download waits for the stopped yt-dlp to exit`() async throws {
        let folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let log = folder.appendingPathComponent("runs.log")
        let slowToStop = try fakeYTDLP("""
        echo start >> '\(log.path)'
        trap 'sleep 0.5; echo end >> "\(log.path)"; exit 0' TERM
        while :; do sleep 0.1; done
        """)
        let client = YTDLPClient()
        let url = try #require(URL(string: "https://example.com/watch?v=abc"))
        let download = { Task { for try await _ in
                client.downloadStream(url: url, into: folder, binaries: slowToStop) {}
        } }

        let first = download()
        try await Task.sleep(for: .milliseconds(400))
        first.cancel()
        let second = download()
        try await Task.sleep(for: .milliseconds(1500))
        second.cancel()

        let lines = try String(contentsOf: log, encoding: .utf8).split(separator: "\n").map(String.init)
        #expect(Array(lines.prefix(3)) == ["start", "end", "start"])
    }

    @Test func `a stalled version check is stopped and its process killed`() async throws {
        let stalled = try fakeYTDLP("exec sleep 10")
        var client = YTDLPClient()
        client.versionTimeout = .milliseconds(300)
        let start = ContinuousClock.now
        #expect(await client.version(binaries: stalled) == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    /// A yt-dlp that ignores the stop request is killed after the grace period.
    @Test func `a version check that ignores the stop is killed`() async throws {
        let stubborn = try fakeYTDLP("trap '' TERM; while :; do sleep 0.1; done")
        var client = YTDLPClient()
        client.versionTimeout = .milliseconds(300)
        let start = ContinuousClock.now
        #expect(await client.version(binaries: stubborn) == nil)
        #expect(ContinuousClock.now - start < .seconds(5))
    }

    /// Each yt-dlp's output is read on its own: a quiet one (a cold start, a slow
    /// page) used to hold back every other one's, downloads' progress included.
    @Test func `a quiet yt-dlp doesn't hold back another one's output`() async throws {
        let quiet = try fakeYTDLP("exec sleep 10")
        // One line in two writes, ended the Windows way: lines are joined across reads.
        let answering = try fakeYTDLP(#"printf 2026.; sleep 0.1; printf '10.21\r\n'"#)
        let client = YTDLPClient()
        let waiting = Task { await client.version(binaries: quiet) }
        defer { waiting.cancel() }
        try await Task.sleep(for: .milliseconds(300))
        let start = ContinuousClock.now
        #expect(await client.version(binaries: answering) == "2026.10.21")
        #expect(ContinuousClock.now - start < .seconds(5))
    }
}
