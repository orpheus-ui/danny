@testable import Danny
import Foundation
import Synchronization
import Testing

struct OrganizingTests {
    private let scratch = TestScratch()

    private func site(_ link: String) throws -> String? {
        try SiteFolder.name(for: #require(URL(string: link)))
    }

    // MARK: Templates

    @Test func `each preset maps to a yt-dlp template that ends in the video id`() {
        #expect(FilenameTemplate.title.ytdlp == "%(title).120B [%(id)s]")
        #expect(FilenameTemplate.titleAndSite.ytdlp == "%(title).100B - %(webpage_url_domain)s [%(id)s]")
        #expect(FilenameTemplate.dateAndTitle.ytdlp == "%(upload_date>%Y-%m-%d|undated)s - %(title).100B [%(id)s]")
        // ExistingFiles finds a video by the id before the extension.
        #expect(FilenameTemplate.allCases.allSatisfy { $0.ytdlp.hasSuffix("[%(id)s]") })
    }

    @Test func `the output argument joins folder, template, suffix and extension`() {
        let folder = URL(fileURLWithPath: "/Users/me/Downloads/Danny/youtube.com")
        #expect(YTDLPClient.outputArguments(in: folder) == ["-o", folder.path + "/%(title).120B [%(id)s].%(ext)s"])
        let kept = YTDLPClient.outputArguments(in: folder, template: .dateAndTitle, suffix: " (2)")
        #expect(kept == ["-o", folder.path + "/" + FilenameTemplate.dateAndTitle.ytdlp + " (2).%(ext)s"])
    }

    @Test func `the preview shows the name, in its site folder when that is on`() {
        #expect(FilenameTemplate.title.preview(siteFolder: false) == "Big Buck Bunny [aqz-KE-bpKQ].mp4")
        #expect(FilenameTemplate.titleAndSite.preview(siteFolder: false)
            == "Big Buck Bunny - youtube.com [aqz-KE-bpKQ].mp4")
        #expect(FilenameTemplate.dateAndTitle.preview(siteFolder: true)
            == "youtube.com/2008-04-10 - Big Buck Bunny [aqz-KE-bpKQ].mp4")
    }

    // MARK: Site folders

    @Test func `the site folder drops www and m but keeps other subdomains`() throws {
        #expect(try site("https://www.youtube.com/watch?v=x") == "youtube.com")
        #expect(try site("https://m.youtube.com/watch?v=x") == "youtube.com")
        #expect(try site("https://WWW.Example.COM/a") == "example.com")
        #expect(try site("https://vimeo.com/1") == "vimeo.com")
        #expect(try site("https://player.vimeo.com/video/1") == "player.vimeo.com")
        #expect(try site("https://example.com:8080/a") == "example.com")
    }

    @Test func `a host that is only a prefix and a name is kept whole`() throws {
        #expect(try site("https://m.com/a") == "m.com")
        #expect(try site("https://www.com/a") == "www.com")
        #expect(try site("http://localhost:3000/a") == "localhost")
    }

    @Test func `a link without a host has no site folder`() throws {
        #expect(try site("file:///tmp/clip.mp4") == nil)
    }

    @Test func `the folder is the chosen one unless a folder per site is on`() throws {
        let root = URL(fileURLWithPath: "/Downloads/Danny", isDirectory: true)
        let link = try #require(URL(string: "https://www.youtube.com/watch?v=x"))
        #expect(SiteFolder.directory(for: link, in: root, perSite: false) == root)
        #expect(SiteFolder.directory(for: link, in: root, perSite: true).path == "/Downloads/Danny/youtube.com")
        let local = try #require(URL(string: "file:///tmp/clip.mp4"))
        #expect(SiteFolder.directory(for: local, in: root, perSite: true) == root)
    }

    // MARK: Settings

    @Test func `settings start with the plain title in one folder and remember changes`() {
        let defaults = scratch.defaults()
        let first = AppSettings(defaults: defaults)
        #expect(first.filenameTemplate == .title)
        #expect(!first.folderPerSite)
        first.filenameTemplate = .dateAndTitle
        first.folderPerSite = true
        let second = AppSettings(defaults: defaults)
        #expect(second.filenameTemplate == .dateAndTitle)
        #expect(second.folderPerSite)
    }

    // MARK: Downloads

    /// Records where a download goes and what it is called, and writes the file there.
    final class RecordingEngine: DownloadEngine {
        let directories = Mutex<[URL]>([])
        let templates = Mutex<[String]>([])

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
            directories.withLock { $0.append(directory) }
            templates.withLock { $0.append(extraArguments.lastIndex(of: "-o").map { extraArguments[$0 + 1] } ?? "") }
            let path = directory.appendingPathComponent("Clip [abc].mp4").path
            return AsyncThrowingStream { continuation in
                continuation.yield(.outputFile(path))
                continuation.finish()
            }
        }
    }

    @MainActor
    private func manager(_ engine: RecordingEngine, in folder: URL, configure: (AppSettings) -> Void = { _ in })
        -> DownloadManager
    {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.downloadDirectory = folder
        settings.existingFiles = .ask
        configure(settings)
        let binaries = YTDLPClient.Binaries(ytdlp: URL(fileURLWithPath: "/bin/sh"), ffmpegDirectory: nil)
        return DownloadManager(settings: settings, client: engine, binaries: binaries, persists: false)
    }

    @MainActor
    private func settle(_ manager: DownloadManager, until status: ItemStatus) async throws {
        for _ in 0 ..< 200 where manager.items.first?.status != status {
            try await Task.sleep(for: .milliseconds(10))
        }
        #expect(manager.items.first?.status == status)
    }

    @MainActor
    private func add(_ manager: DownloadManager) throws {
        try manager.add(url: #require(URL(string: "https://www.example.com/watch?v=abc")))
    }

    @MainActor
    @Test func `a download goes to the site folder under the chosen template`() async throws {
        let folder = scratch.folder()
        let engine = RecordingEngine()
        let manager = manager(engine, in: folder) {
            $0.folderPerSite = true
            $0.filenameTemplate = .titleAndSite
        }
        try add(manager)
        try await settle(manager, until: .finished)
        #expect(engine.directories.withLock { $0.map(\.path) } == [folder.appendingPathComponent("example.com").path])
        #expect(engine.templates.withLock { $0 }
            == [folder.appendingPathComponent("example.com/\(FilenameTemplate.titleAndSite.ytdlp).%(ext)s").path])
    }

    @MainActor
    @Test func `a download stays in the chosen folder when the setting is off`() async throws {
        let folder = scratch.folder()
        let engine = RecordingEngine()
        let manager = manager(engine, in: folder)
        try add(manager)
        try await settle(manager, until: .finished)
        #expect(engine.directories.withLock { $0.map(\.path) } == [folder.path])
    }

    @MainActor
    @Test(arguments: [true, false]) func `a file in the flat or the site folder is found whatever the setting`(
        perSite: Bool,
    ) async throws {
        for place in ["", "example.com"] {
            let folder = scratch.folder().appendingPathComponent("root")
            let directory = place.isEmpty ? folder : folder.appendingPathComponent(place)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Data().write(to: directory.appendingPathComponent("2008-04-10 - Clip [abc].mp4"))
            let engine = RecordingEngine()
            let manager = manager(engine, in: folder) { $0.folderPerSite = perSite }
            try add(manager)
            try await settle(manager, until: .existing)
            #expect(engine.directories.withLock { $0 }.isEmpty)
        }
    }
}
