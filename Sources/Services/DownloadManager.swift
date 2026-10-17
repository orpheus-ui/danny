import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager {
    private(set) var items: [DownloadItem] = []
    var sortOrder: SortOrder = .newest
    var filter = DownloadFilter()
    var pendingManualAdd = false
    private(set) var lastFailureMessage: String?
    /// The last yt-dlp update check, for Settings: nil until one has run.
    private(set) var engineCheck: YTDLPUpdater.Check?
    private(set) var isCheckingEngine = false

    let settings: AppSettings
    /// Signed-in sites; a run passes the link's site cookies to yt-dlp when present.
    var sessions: SiteSessions?

    let client: any DownloadEngine
    private var binaries: YTDLPClient.Binaries = .missing
    /// The runs in flight; the Mac stays awake while there are any.
    private var runningTasks: [UUID: Task<Void, Never>] = [:] {
        didSet { keepAwake.isHeld = !runningTasks.isEmpty }
    }

    private let keepAwake: any KeepAwake
    private var fallbackAttempted: Set<UUID> = []
    private var saveDebounce: Task<Void, Never>?
    /// `-sample-queue` (debug builds): one card per state, in memory only.
    private var isSampleQueue = false
    /// False in tests: the queue neither loads nor saves the history file.
    private let persists: Bool
    /// Replace's way to drop the old file; tests delete their own file instead.
    var moveToTrash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    var activeCount: Int {
        items.filter(\.status.isActive).count
    }

    var visibleItems: [DownloadItem] {
        var result = filter.isEmpty ? items : items.filter(filter.matches)
        switch sortOrder {
        case .newest: result.sort { $0.addedAt > $1.addedAt }
        case .oldest: result.sort { $0.addedAt < $1.addedAt }
        case .name: result.sort { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
        case .size:
            result.sort { ($0.totalBytes ?? -1) > ($1.totalBytes ?? -1) }
        case .status: result.sort { $0.status < $1.status }
        }
        return result
    }

    init(
        settings: AppSettings, client: any DownloadEngine = YTDLPClient(),
        binaries: YTDLPClient.Binaries? = nil, persists: Bool = true, keepAwake: any KeepAwake = SystemKeepAwake(),
    ) {
        self.keepAwake = keepAwake
        self.settings = settings
        self.client = client
        self.persists = persists
        self.binaries = binaries ?? YTDLPClient.locateBinaries()
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sample-queue") {
                items = DownloadItem.samples
                isSampleQueue = true
                return
            }
        #endif
        let restored = (persists ? PersistenceStore.load() : []).map { item -> DownloadItem in
            var item = item
            if item.status.isActive {
                item.status = .queued
                item.fractionCompleted = nil
                item.speedBytesPerSecond = nil
            }
            return item
        }
        items = restored.sorted { $0.addedAt > $1.addedAt }
        pump()
    }

    func refreshBinaries() {
        binaries = YTDLPClient.locateBinaries()
    }

    @discardableResult
    func add(url: URL) -> Bool {
        let normalized = Self.normalize(url)
        if let existing = items.first(where: {
            Self.normalize($0.sourceURL) == normalized && $0.status.isActive
        }) {
            _ = existing
            return false
        }
        var item = DownloadItem(url: normalized)
        item.title = normalized.host ?? normalized.absoluteString
        items.insert(item, at: 0)
        saveSoon()
        pump()
        return true
    }

    static func normalize(_ url: URL) -> URL {
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.fragment = nil
        return components.url ?? url
    }

    func cancel(id: UUID) {
        runningTasks[id]?.cancel()
        runningTasks[id] = nil
        if let index = items.firstIndex(where: { $0.id == id }), items[index].status.isActive {
            if [.choosing, .existing].contains(items[index].status) {
                // No run is left to resume a card waiting for its pick: stop it
                // where Retry can start it again.
                items[index].qualityOptions = nil
                items[index].choiceDeadline = nil
                items[index].existingFile = nil
                fail(itemID: id, message: "Cancelled")
                return
            }
            items[index].status = .queued
            items[index].speedBytesPerSecond = nil
            saveSoon()
        }
    }

    func retry(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .queued
        items[index].fractionCompleted = nil
        items[index].downloadedBytes = nil
        items[index].speedBytesPerSecond = nil
        items[index].errorMessage = nil
        items[index].filePath = nil
        saveSoon()
        pump()
    }

    /// Removes the card; an unfinished one takes its partial files with it.
    func remove(id: UUID) {
        let item = items.first { $0.id == id }
        let run = runningTasks[id]
        cancel(id: id)
        items.removeAll { $0.id == id }
        saveSoon()
        if let item, item.status != .finished { removePartials(of: item, after: run) }
    }

    func clearFinished() {
        let failed = items.filter { $0.status == .failed }
        items.removeAll { !$0.status.isActive }
        saveSoon()
        for item in failed {
            removePartials(of: item, after: nil)
        }
    }

    func pump() {
        guard !isSampleQueue else { return }
        // Running downloads only: queued cards and cards waiting for a pick don't
        // hold a slot.
        while runningTasks.count < max(1, settings.maxConcurrentDownloads),
              let next = items.last(where: { $0.status == .queued && runningTasks[$0.id] == nil })
        {
            start(item: next)
        }
    }

    private func start(item: DownloadItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].status = .resolving
        items[index].errorMessage = nil
        items[index].existingFile = nil
        let task = Task { [weak self] in
            guard let self else { return }
            await run(itemID: item.id)
        }
        runningTasks[item.id] = task
    }

    private func run(itemID: UUID) async {
        defer {
            runningTasks[itemID] = nil
            pump()
        }

        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        let url = items[index].sourceURL

        guard engineIsInstalled(for: itemID) else { return }

        // The signed-in site's cookies, on disk only while this run lasts; refreshed
        // ones go back to the browser store afterwards.
        let cookieFile = await sessions?.cookieFile(for: url)
        defer {
            if let cookieFile {
                Task { [sessions] in
                    if let sessions { await sessions.finish(cookieFile, for: url) } else { cookieFile.remove() }
                }
            }
        }
        let signedIn = cookieFile?.arguments ?? []
        var cookies = signedIn

        do {
            guard let metadata = try await probe(itemID: itemID, url: url, signedIn: &cookies) else { return }

            guard let choice = qualityChoice(for: itemID, metadata: metadata) else { return }
            let quality = QualitySelection.arguments(for: choice, format: settings.format)
            guard let output = try await existingFileCheck(for: itemID, videoID: metadata.id, choice: choice)
            else { return }

            let path = try await download(
                itemID: itemID, url: url, arguments: cookies + quality + output, signedIn: signedIn,
                planned: metadata.plannedFiles,
            )
            await finish(itemID: itemID, path: path)
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            fail(itemID: itemID, message: Self.hinted(error.localizedDescription, updates: settings.keepsEngineCurrent))
        }
    }

    /// Downloads, retrying once with other YouTube clients when the first try is refused,
    /// and with the session's `signedIn` cookies when a signed-out try asks for a sign-in.
    private func download(
        itemID: UUID, url: URL, arguments: [String], signedIn: [String], planned: [String: Int64],
    ) async throws -> String? {
        do {
            return try await downloadPhase(itemID: itemID, url: url, extraArguments: arguments, planned: planned)
        } catch let error as YTDLPError
            where !fallbackAttempted.contains(itemID)
            && Self.shouldRetry(after: error.message, tried: arguments, signedIn: signedIn)
        {
            fallbackAttempted.insert(itemID)
            return try await downloadPhase(
                itemID: itemID, url: url,
                extraArguments: Self.retryArguments(after: error.message, tried: arguments, signedIn: signedIn),
                planned: planned,
            )
        }
    }

    /// Probes signed out first where the site prefers it, and again signed in when the
    /// link asks for it. `cookies` ends as the set the download uses.
    private func probe(itemID: UUID, url: URL, signedIn cookies: inout [String]) async throws -> VideoMetadata? {
        let signedIn = cookies
        cookies = Self.firstTryCookies(for: url, signedIn: signedIn)
        do {
            return try await probe(itemID: itemID, url: url, cookies: cookies)
        } catch let error as YTDLPError where cookies != signedIn && DownloadItem.asksForSignIn(error.message) {
            cookies = signedIn
            return try await probe(itemID: itemID, url: url, cookies: cookies)
        }
    }

    /// Reads the link's details and puts them on the card. With the quality known,
    /// the probe lists the very files the download fetches. Nil when the card was
    /// cancelled or removed meanwhile.
    private func probe(itemID: UUID, url: URL, cookies: [String]) async throws -> VideoMetadata? {
        let preset = items.first(where: { $0.id == itemID })?.quality ?? settings.quality.choice
        let presetArguments = preset.map { QualitySelection.arguments(for: $0, format: settings.format) } ?? []
        let metadata = try await client.probe(url: url, binaries: binaries, extraArguments: cookies + presetArguments)
        guard let index = items.firstIndex(where: { $0.id == itemID }),
              items[index].status == .resolving else { return nil }
        items[index].title = metadata.title.isEmpty ? items[index].title : metadata.title
        items[index].videoID = metadata.id
        items[index].resolution = metadata.resolutionLabel
        items[index].totalBytes = metadata.filesizeApprox
        items[index].thumbnailURL = metadata.thumbnail.flatMap(URL.init(string:))
        saveSoon()
        return metadata
    }

    // MARK: Quality

    /// Fails the item with install steps when yt-dlp can't be found.
    private func engineIsInstalled(for itemID: UUID) -> Bool {
        guard !binaries.ytdlp.fileExistsAsExecutable else { return true }
        fail(
            itemID: itemID,
            message: """
            yt-dlp not found. Install with `brew install yt-dlp ffmpeg` \
            or run scripts/fetch-dependencies.sh.
            """,
        )
        return false
    }

    private func downloadPhase(
        itemID: UUID, url: URL, extraArguments: [String], planned: [String: Int64],
    ) async throws -> String? {
        guard !Task.isCancelled, let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        items[index].status = .downloading
        var finalPath: String?
        var progress = DownloadProgress(planned: planned)
        for try await event in client.downloadStream(
            url: url, into: outputDirectory, binaries: binaries, extraArguments: extraArguments,
        ) {
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
            switch event {
            case let .progress(downloaded, total, speed, file):
                items[index].fractionCompleted = progress.update(file: file, downloaded: downloaded, total: total)
                if let totalBytes = progress.totalBytes {
                    items[index].totalBytes = totalBytes
                }
                items[index].speedBytesPerSecond = speed
            case let .outputFile(path):
                finalPath = path
            case let .alreadyDownloaded(path):
                items[index].existingFile = ExistingFile(path: path)
            }
        }
        return finalPath
    }

    /// Changes one item in place; how the manager's extensions in other files write.
    func updateItem(_ id: UUID, _ body: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        body(&items[index])
    }

    var outputDirectory: URL { settings.downloadDirectory }

    func toolVersions() async -> String {
        async let ytdlpVersion = client.version(binaries: binaries)
        let ffmpegInstalled = binaries.ffmpegDirectory != nil
        let ytdlpText = await (ytdlpVersion) ?? "not found"
        return "yt-dlp \(ytdlpText) · ffmpeg \(ffmpegInstalled ? "found" : "missing")"
    }

    func fail(itemID: UUID, message: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .failed
        items[index].errorMessage = message
        items[index].speedBytesPerSecond = nil
        lastFailureMessage = message
        saveSoon()
    }

    func saveSoon() {
        guard !isSampleQueue, persists else { return }
        saveDebounce?.cancel()
        saveDebounce = Task { [items] in
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            PersistenceStore.save(items)
        }
    }
}

extension URL {
    var fileExistsAsExecutable: Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}

// MARK: - Engine updates

extension DownloadManager {
    /// Fetches the latest yt-dlp: at launch when the setting allows, and whenever
    /// Settings' Check Now asks (`manual`). A new copy is used from the next download
    /// on; running ones keep theirs.
    func checkEngine(with updater: YTDLPUpdater = YTDLPUpdater(), manual: Bool = false) async {
        guard manual || settings.keepsEngineCurrent, !isSampleQueue, !isCheckingEngine else { return }
        isCheckingEngine = true
        defer { isCheckingEngine = false }
        let installed = await client.version(binaries: binaries)
        let outcome = await updater.update(from: installed)
        if case .updated = outcome { refreshBinaries() }
        engineCheck = YTDLPUpdater.Check(outcome: outcome, date: .now)
    }
}
