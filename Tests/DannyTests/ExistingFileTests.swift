@testable import Danny
import Foundation
import Synchronization
import Testing

/// A second download of a video already in the folder asks first, instead of
/// yt-dlp skipping it and the card claiming a file it didn't make.
@MainActor
struct ExistingFileTests {
    /// Stands in for yt-dlp: a fixed probe, and a download that records the name
    /// suffix its arguments ask for ("" for the default name).
    final class FakeEngine: DownloadEngine {
        let suffixes = Mutex<[String]>([])
        let skipsAsExisting: String?

        init(skipsAsExisting: String? = nil) {
            self.skipsAsExisting = skipsAsExisting
        }

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
            // yt-dlp takes the last -o; the client's own comes before these arguments.
            let template = extraArguments.lastIndex(of: "-o").map { extraArguments[$0 + 1] } ?? ""
            let suffix = template.components(separatedBy: "[%(id)s]").last?
                .components(separatedBy: ".%(ext)s").first ?? ""
            suffixes.withLock { $0.append(suffix) }
            let path = skipsAsExisting ?? directory.appendingPathComponent("Clip [abc]\(suffix).mp4").path
            let skipped = skipsAsExisting != nil
            return AsyncThrowingStream { continuation in
                if skipped { continuation.yield(.alreadyDownloaded(path)) }
                continuation.yield(.outputFile(path))
                continuation.finish()
            }
        }

        var calledSuffixes: [String] { suffixes.withLock { $0 } }
    }

    private let folder: URL

    init() throws {
        folder = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString).appendingPathComponent("Danny")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func manager(_ engine: FakeEngine, policy: ExistingFilePolicy = .ask) throws -> DownloadManager {
        let settings = try AppSettings(defaults: #require(UserDefaults(suiteName: UUID().uuidString)))
        settings.downloadDirectory = folder.deletingLastPathComponent()
        settings.existingFiles = policy
        let binaries = YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil)
        return DownloadManager(settings: settings, client: engine, binaries: binaries, persists: false)
    }

    /// The temporary directory is behind /var → /private/var, and listings give the real path.
    private func same(_ path: String?, _ file: URL) -> Bool {
        path.map { URL(fileURLWithPath: $0).resolvingSymlinksInPath() } == file.resolvingSymlinksInPath()
    }

    @discardableResult
    private func file(_ name: String) throws -> URL {
        let url = folder.appendingPathComponent(name)
        try Data().write(to: url)
        return url
    }

    private func settle(_ manager: DownloadManager, until status: ItemStatus) async throws -> DownloadItem {
        for _ in 0 ..< 200 where manager.items.first?.status != status {
            try await Task.sleep(for: .milliseconds(10))
        }
        let item = try #require(manager.items.first)
        #expect(item.status == status)
        return item
    }

    private func add(_ manager: DownloadManager) throws {
        try manager.add(url: #require(URL(string: "https://example.com/watch?v=abc")))
    }

    @Test func `asks before downloading a video already in the folder`() async throws {
        let old = try file("Old title [abc].mp4")
        let engine = FakeEngine()
        let manager = try manager(engine)
        try add(manager)
        let item = try await settle(manager, until: .existing)
        #expect(same(item.existingFile?.path, old))
        #expect(engine.calledSuffixes.isEmpty)
    }

    @Test func `downloads as usual when the folder has only other files`() async throws {
        try file("Clip [abc].m4a")
        try file("Clip [abc].f137.mp4")
        try file("Clip [abc].mp4.part")
        try file("Other [xyz].mp4")
        let engine = FakeEngine()
        let manager = try manager(engine)
        try add(manager)
        _ = try await settle(manager, until: .finished)
        #expect(engine.calledSuffixes == [""])
    }

    @Test func `keep both downloads beside the old file under the first free number`() async throws {
        try file("Clip [abc].mp4")
        try file("Clip [abc] (2).mp4")
        let engine = FakeEngine()
        let manager = try manager(engine)
        try add(manager)
        let item = try await settle(manager, until: .existing)
        manager.resolveExisting(id: item.id, with: .keepBoth)
        let done = try await settle(manager, until: .finished)
        #expect(engine.calledSuffixes == [" (3)"])
        #expect(done.filePath?.hasSuffix("Clip [abc] (3).mp4") == true)
    }

    @Test func `replace moves the old file to the Trash and downloads again`() async throws {
        let old = try file("Clip [abc].webm")
        let engine = FakeEngine()
        let manager = try manager(engine, policy: .replace)
        try add(manager)
        _ = try await settle(manager, until: .finished)
        #expect(!FileManager.default.fileExists(atPath: old.path))
        #expect(engine.calledSuffixes == [""])
    }

    @Test func `keeping the old file ends the card on it`() async throws {
        let old = try file("Clip [abc].mp4")
        let manager = try manager(FakeEngine())
        try add(manager)
        let item = try await settle(manager, until: .existing)
        manager.keepExisting(id: item.id)
        let done = try #require(manager.items.first)
        #expect(done.status == .finished)
        #expect(same(done.filePath, old))
    }

    @Test func `a download yt-dlp skips as already there asks too`() async throws {
        let path = folder.appendingPathComponent("Clip [abc].mkv").path
        let manager = try manager(FakeEngine(skipsAsExisting: path))
        try add(manager)
        let item = try await settle(manager, until: .existing)
        #expect(item.existingFile?.path == path)
    }

    @Test func `reads yt-dlp's already-downloaded line`() {
        let line = "[download] /Users/me/Downloads/Danny/Clip [abc].mp4 has already been downloaded"
        #expect(YTDLPClient.alreadyDownloadedPath(line) == "/Users/me/Downloads/Danny/Clip [abc].mp4")
        #expect(YTDLPClient.alreadyDownloadedPath("[download] Destination: /x.mp4") == nil)
    }
}
