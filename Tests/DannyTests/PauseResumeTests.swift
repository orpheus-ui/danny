@testable import Danny
import Foundation
import Synchronization
import Testing

/// Pause stops a card's yt-dlp but keeps what it downloaded, so the next run continues
/// it; Cancel stops it for good and deletes those files. Paused cards stay paused
/// across a quit.
@MainActor
struct PauseResumeTests {
    /// Where a run was told to download, and with which arguments.
    struct Destination: Equatable {
        var directory: URL
        var arguments: [String]
    }

    /// Stands in for yt-dlp: a download that reports half its bytes, then waits until
    /// its run is stopped, like a long download.
    final class HangingEngine: DownloadEngine {
        private let runs = Mutex(0)
        var downloadRuns: Int { runs.withLock { $0 } }
        let destinations = Mutex<[Destination]>([])

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
            runs.withLock { $0 += 1 }
            destinations.withLock { $0.append(Destination(directory: directory, arguments: extraArguments)) }
            return AsyncThrowingStream { continuation in
                continuation.yield(.progress(downloaded: 50, total: 100, speedBytesPerSecond: 1000))
            }
        }
    }

    private let scratch = TestScratch()
    private let folder: URL
    private let engine = HangingEngine()

    init() throws {
        folder = scratch.folder()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }

    private func manager(maxConcurrent: Int = 3) -> DownloadManager {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = folder
        settings.maxConcurrentDownloads = maxConcurrent
        let binaries = YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil)
        return DownloadManager(settings: settings, client: engine, binaries: binaries, persists: false)
    }

    @discardableResult
    private func add(_ manager: DownloadManager, _ link: String = "https://example.com/watch?v=abc") throws -> UUID {
        try manager.add(url: #require(URL(string: link)))
        return try #require(manager.items.first?.id)
    }

    private func item(_ manager: DownloadManager, _ id: UUID) -> DownloadItem? {
        manager.items.first { $0.id == id }
    }

    /// Waits until the card is downloading and has reported its half.
    private func halfway(_ manager: DownloadManager, _ id: UUID) async throws {
        for _ in 0 ..< 200 where item(manager, id)?.fractionCompleted == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(item(manager, id)?.status == .downloading)
        #expect(item(manager, id)?.fractionCompleted == 0.5)
    }

    private func partial() throws -> URL {
        let url = folder.appendingPathComponent("Clip [abc].mp4.part")
        try Data("half".utf8).write(to: url)
        return url
    }

    @Test func `pause keeps the card's progress and its partial file`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        let part = try partial()

        manager.pause(id: id)
        #expect(item(manager, id)?.status == .paused)
        #expect(item(manager, id)?.fractionCompleted == 0.5)
        #expect(item(manager, id)?.speedBytesPerSecond == nil)

        // The stopped run must neither finish the card nor take its file.
        try await Task.sleep(for: .milliseconds(1500))
        #expect(item(manager, id)?.status == .paused)
        #expect(FileManager.default.fileExists(atPath: part.path))
    }

    @Test func `resume starts the paused card again`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        manager.pause(id: id)

        manager.resume(id: id)
        #expect(item(manager, id)?.status == .resolving)
        for _ in 0 ..< 200 where engine.downloadRuns < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(engine.downloadRuns == 2)
        #expect(item(manager, id)?.status == .downloading)
    }

    /// Settings changed while paused must not move the card: yt-dlp would start over and
    /// the `.part` files would stay behind.
    @Test func `resume keeps the destination and format the run started with`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        manager.pause(id: id)

        manager.settings.downloadDirectory = scratch.folder()
        manager.settings.folderPerSite = true
        manager.settings.filenameTemplate = .dateAndTitle
        manager.settings.format = .highest
        manager.settings.quality = .upTo720
        manager.resume(id: id)
        for _ in 0 ..< 200 where engine.downloadRuns < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        let runs = engine.destinations.withLock { $0 }
        #expect(runs.count == 2)
        #expect(runs.first?.directory == folder)
        #expect(runs.last == runs.first)
    }

    @Test func `cancel after a settings change deletes the partial file where the run started`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        let part = try partial()
        manager.pause(id: id)

        manager.settings.downloadDirectory = scratch.folder()
        manager.cancel(id: id)
        for _ in 0 ..< 300 where FileManager.default.fileExists(atPath: part.path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!FileManager.default.fileExists(atPath: part.path))
    }

    @Test func `a retry after a failure uses the current settings`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        manager.pause(id: id)
        manager.fail(itemID: id, message: "Network down")

        manager.settings.folderPerSite = true
        manager.retry(id: id)
        for _ in 0 ..< 200 where engine.downloadRuns < 2 {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(engine.destinations.withLock { $0.last?.directory.path } == folder.appendingPathComponent("example.com")
            .path)
    }

    @Test func `a saved run without a stored destination still loads`() throws {
        let item = try DownloadItem(url: #require(URL(string: "https://example.com/watch?v=abc")))
        let encoded = try JSONEncoder().encode([item])
        var json = try #require(JSONSerialization.jsonObject(with: encoded) as? [[String: Any]])
        json[0].removeValue(forKey: "run")
        let old = try JSONSerialization.data(withJSONObject: json)
        #expect(try JSONDecoder().decode([DownloadItem].self, from: old).first?.run == nil)
    }

    @Test func `a paused card's destination survives a quit`() throws {
        var item = try DownloadItem(url: #require(URL(string: "https://example.com/watch?v=abc")))
        item.status = .paused
        item.run = DownloadRun(directory: folder, format: ["-f", "best"], output: ["-o", "x"])
        let file = folder.appendingPathComponent("history.json")
        PersistenceStore.save([item], to: file)
        #expect(PersistenceStore.load(from: file).first?.run == item.run)
    }

    @Test func `a paused card frees its slot for the next one`() throws {
        let manager = manager(maxConcurrent: 1)
        let first = try add(manager, "https://example.com/watch?v=one")
        let second = try add(manager, "https://example.com/watch?v=two")
        #expect(item(manager, second)?.status == .queued)
        manager.pause(id: first)
        #expect(item(manager, second)?.status == .resolving)
    }

    @Test func `pause all and resume all`() throws {
        let manager = manager(maxConcurrent: 1)
        let running = try add(manager, "https://example.com/watch?v=one")
        let waiting = try add(manager, "https://example.com/watch?v=two")
        #expect(manager.canPauseAll)

        manager.pauseAll()
        #expect(item(manager, running)?.status == .paused)
        #expect(item(manager, waiting)?.status == .paused)
        #expect(!manager.canPauseAll)
        #expect(manager.canResumeAll)

        manager.resumeAll()
        #expect(manager.items.allSatisfy { $0.status != .paused })
        // The older card gets the one slot again.
        #expect(item(manager, running)?.status == .resolving)
        #expect(item(manager, waiting)?.status == .queued)
    }

    @Test func `cancel stops the card and deletes its partial file`() async throws {
        let manager = manager()
        let id = try add(manager)
        try await halfway(manager, id)
        let part = try partial()

        manager.cancel(id: id)
        #expect(item(manager, id)?.status == .failed)
        #expect(item(manager, id)?.errorMessage == "Cancelled")
        for _ in 0 ..< 300 where FileManager.default.fileExists(atPath: part.path) {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(!FileManager.default.fileExists(atPath: part.path))
        // No new run starts behind it.
        try await Task.sleep(for: .milliseconds(200))
        #expect(engine.downloadRuns == 1)
        #expect(item(manager, id)?.status == .failed)
    }

    @Test func `a paused card's history survives a quit`() throws {
        var item = try DownloadItem(url: #require(URL(string: "https://example.com/watch?v=abc")))
        item.status = .paused
        item.fractionCompleted = 0.59
        let file = folder.appendingPathComponent("history.json")
        PersistenceStore.save([item], to: file)
        let loaded = try #require(PersistenceStore.load(from: file).first)
        #expect(loaded.id == item.id)
        #expect(loaded.status == .paused)
        #expect(loaded.fractionCompleted == 0.59)
    }

    @Test func `on launch, paused cards stay paused and running ones start again`() throws {
        let url = try #require(URL(string: "https://example.com/watch?v=abc"))
        var paused = DownloadItem(url: url)
        paused.status = .paused
        paused.fractionCompleted = 0.59
        var running = DownloadItem(url: url)
        running.status = .downloading
        running.fractionCompleted = 0.3
        running.speedBytesPerSecond = 1000
        var done = DownloadItem(url: url)
        done.status = .finished

        let restored = DownloadManager.restored([paused, running, done])
        #expect(restored[0].status == .paused)
        #expect(restored[0].fractionCompleted == 0.59)
        #expect(restored[1].status == .queued)
        #expect(restored[1].speedBytesPerSecond == nil)
        #expect(restored[2].status == .finished)
    }
}
