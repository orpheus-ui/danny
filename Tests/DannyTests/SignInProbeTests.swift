@testable import Danny
import Foundation
import Synchronization
import Testing

/// A site that signs in only when asked is tried signed out first; when the probe asks
/// for a sign-in, the run goes on with the session's cookies.
@MainActor
struct SignInProbeTests {
    /// Asks for a sign-in until the arguments carry cookies.
    final class SignInEngine: DownloadEngine {
        let probes = Mutex<[[String]]>([])
        let downloads = Mutex<[[String]]>([])

        @concurrent
        func probe(url _: URL, binaries _: YTDLPClient.Binaries, extraArguments: [String]) async throws
            -> VideoMetadata
        {
            probes.withLock { $0.append(extraArguments) }
            guard extraArguments.contains("--cookies") else {
                throw YTDLPError(message: "ERROR: [youtube] abc: Sign in to confirm you're not a bot")
            }
            return try JSONDecoder().decode(VideoMetadata.self, from: Data(#"{"id":"abc","title":"Clip"}"#.utf8))
        }

        @concurrent
        func version(binaries _: YTDLPClient.Binaries) async -> String? { nil }

        func downloadStream(
            url _: URL, into directory: URL, binaries _: YTDLPClient.Binaries, extraArguments: [String],
        ) -> AsyncThrowingStream<DownloadEvent, Error> {
            downloads.withLock { $0.append(extraArguments) }
            let path = directory.appendingPathComponent("Clip [abc].mp4").path
            return AsyncThrowingStream { continuation in
                continuation.yield(.outputFile(path))
                continuation.finish()
            }
        }
    }

    /// Hands out a cookie file and counts the runs it was handed back from.
    final class FakeSessions: CookieSource {
        let file = TemporaryCookieFile(url: URL(fileURLWithPath: "/tmp/fake-cookies.txt"), written: [:], generation: 0)
        private(set) var finished = 0

        func cookieFile(for _: URL) async -> TemporaryCookieFile? { file }
        func finish(_: TemporaryCookieFile, for _: URL) async { finished += 1 }
    }

    private let scratch = TestScratch()

    private func settle(_ manager: DownloadManager) async throws {
        for _ in 0 ..< 200 where manager.items.first?.status != .finished {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == .finished)
    }

    @Test func `a probe that asks for a sign-in is retried with the cookies`() async throws {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = scratch.folder()
        let engine = SignInEngine()
        let sessions = FakeSessions()
        let manager = DownloadManager(
            settings: settings, client: engine,
            binaries: YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil),
            persists: false, keepAwake: KeepAwakeTests.FakeKeepAwake(),
            network: NetworkTests.FakeNetworkPath(isMetered: false),
        )
        manager.sessions = sessions

        try manager.add(url: #require(URL(string: "https://www.youtube.com/watch?v=abc")))
        try await settle(manager)

        let cookies = sessions.file.arguments
        let probes = engine.probes.withLock { $0 }
        #expect(probes.count == 2)
        #expect(probes.first?.contains("--cookies") == false)
        #expect(probes.last?.starts(with: cookies) == true)
        #expect(engine.downloads.withLock { $0 }.first?.starts(with: cookies) == true)
        // `finish` runs in a detached task after the run.
        for _ in 0 ..< 100 where sessions.finished == 0 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(sessions.finished == 1)
    }
}
