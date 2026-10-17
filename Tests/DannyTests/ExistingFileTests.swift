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
        let probeDelay: Duration

        init(skipsAsExisting: String? = nil, probeDelay: Duration = .zero) {
            self.skipsAsExisting = skipsAsExisting
            self.probeDelay = probeDelay
        }

        @concurrent
        func probe(url _: URL, binaries _: YTDLPClient.Binaries, extraArguments _: [String]) async throws
            -> VideoMetadata
        {
            try await Task.sleep(for: probeDelay)
            return try JSONDecoder().decode(VideoMetadata.self, from: Data(#"{"id":"abc","title":"Clip"}"#.utf8))
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

    private let scratch = TestScratch()
    private let folder: URL

    init() throws {
        folder = scratch.folder().appendingPathComponent("Danny")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func manager(_ engine: FakeEngine, policy: ExistingFilePolicy = .ask) throws -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
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
        try file("Reaction to [abc] by someone [xyz].mp4")
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
        manager.moveToTrash = { try FileManager.default.removeItem(at: $0) }
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

    @Test func `removing an unfinished card deletes its partial files only`() async throws {
        let finished = try file("Clip [abc].mp4")
        let partials = try [
            file("Clip [abc] (2).f137.mp4.part"), file("Clip [abc] (2).f251.webm"), file("Clip [abc] (2).mp4.ytdl"),
        ]
        let other = try file("Other [xyz].mp4.part")
        let manager = try manager(FakeEngine())
        try add(manager)
        let item = try await settle(manager, until: .existing)
        manager.remove(id: item.id)
        for _ in 0 ..< 200 where partials.contains(where: { FileManager.default.fileExists(atPath: $0.path) }) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(partials.allSatisfy { !FileManager.default.fileExists(atPath: $0.path) })
        #expect(FileManager.default.fileExists(atPath: finished.path))
        #expect(FileManager.default.fileExists(atPath: other.path))
    }

    @Test func `a run cancelled while it looks at the old file doesn't ask about it`() async throws {
        let elsewhere = scratch.folder()
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let old = elsewhere.appendingPathComponent("Clip [abc].mp4")
        try Data().write(to: old)
        // The probe holds the card in `.resolving`, which counts as active.
        let manager = try manager(FakeEngine(probeDelay: .milliseconds(300)))
        try add(manager)
        let id = try #require(manager.items.first?.id)
        let cancelled = Task { await manager.askAboutExisting(id, file: old) }
        cancelled.cancel()
        await cancelled.value
        _ = try await settle(manager, until: .finished)
    }

    @Test func `reads yt-dlp's already-downloaded line`() {
        let line = "[download] /Users/me/Downloads/Danny/Clip [abc].mp4 has already been downloaded"
        #expect(YTDLPClient.alreadyDownloadedPath(line) == "/Users/me/Downloads/Danny/Clip [abc].mp4")
        #expect(YTDLPClient.alreadyDownloadedPath("[download] Destination: /x.mp4") == nil)
    }
}
