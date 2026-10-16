@testable import Danny
import Foundation
import Testing

/// Removing a card stops its yt-dlp at once, even while yt-dlp prints nothing
/// (reading the page and player can take half a minute without a line).
struct CancellationTests {
    /// A fake yt-dlp that prints one line, goes quiet, then leaves a file behind.
    private func silentEngine() throws -> (YTDLPClient.Binaries, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let marker = directory.appendingPathComponent("finished")
        let script = directory.appendingPathComponent("yt-dlp")
        try Data("#!/bin/sh\necho started\nsleep 2\ntouch '\(marker.path)'\n".utf8).write(to: script)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)
        return (YTDLPClient.Binaries(ytdlp: script, ffmpegDirectory: nil), marker)
    }

    @Test func `cancelling a quiet download stops yt-dlp`() async throws {
        let (binaries, marker) = try silentEngine()
        let client = YTDLPClient()
        let consumer = Task {
            for try await _ in client.downloadStream(
                url: URL(string: "https://example.com/v")!, into: marker.deletingLastPathComponent(),
                binaries: binaries,
            ) {}
        }
        try await Task.sleep(for: .milliseconds(500))
        consumer.cancel()
        try await Task.sleep(for: .seconds(3))
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }

    @Test func `cancelling a quiet probe stops yt-dlp`() async throws {
        let (binaries, marker) = try silentEngine()
        let client = YTDLPClient()
        let consumer = Task { try await client.probe(url: URL(string: "https://example.com/v")!, binaries: binaries) }
        try await Task.sleep(for: .milliseconds(500))
        consumer.cancel()
        try await Task.sleep(for: .seconds(3))
        #expect(!FileManager.default.fileExists(atPath: marker.path))
    }
}
