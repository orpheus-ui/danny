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

    let settings: AppSettings
    /// Signed-in sites; a run passes the link's site cookies to yt-dlp when present.
    var sessions: SiteSessions?

    private let client = YTDLPClient()
    private var binaries: YTDLPClient.Binaries = .missing
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private var fallbackAttempted: Set<UUID> = []
    private var saveDebounce: Task<Void, Never>?
    /// `-sample-queue` (debug builds): one card per state, in memory only.
    private var isSampleQueue = false

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

    init(settings: AppSettings) {
        self.settings = settings
        binaries = YTDLPClient.locateBinaries()
        #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sample-queue") {
                items = DownloadItem.samples
                isSampleQueue = true
                return
            }
        #endif
        let restored = PersistenceStore.load().map { item -> DownloadItem in
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

    func remove(id: UUID) {
        cancel(id: id)
        items.removeAll { $0.id == id }
        saveSoon()
    }

    func clearFinished() {
        for item in items where !item.status.isActive {
            cancel(id: item.id)
        }
        items.removeAll { !$0.status.isActive }
        saveSoon()
    }

    func revealInFinder(id: UUID) {
        guard let path = items.first(where: { $0.id == id })?.filePath else { return }
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: (path as NSString).deletingLastPathComponent)
    }

    private func pump() {
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
        let cookies = cookieFile?.arguments ?? []

        do {
            guard let metadata = try await probe(itemID: itemID, url: url, cookies: cookies) else { return }

            guard let choice = qualityChoice(for: itemID, metadata: metadata) else { return }
            let quality = QualitySelection.arguments(for: choice, format: settings.format)

            let path = try await download(
                itemID: itemID, url: url, arguments: cookies + quality, planned: metadata.plannedFiles,
            )

            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
            items[index].status = .finished
            items[index].fractionCompleted = 1
            items[index].speedBytesPerSecond = nil
            items[index].filePath = path
            saveSoon()
        } catch is CancellationError {
            return
        } catch {
            if Task.isCancelled { return }
            fail(itemID: itemID, message: Self.hinted(error.localizedDescription, url: url))
        }
    }

    /// Downloads, retrying once with YouTube's iOS client when the first try is refused.
    private func download(
        itemID: UUID, url: URL, arguments: [String], planned: [String: Int64],
    ) async throws -> String? {
        do {
            return try await downloadPhase(itemID: itemID, url: url, extraArguments: arguments, planned: planned)
        } catch let error as YTDLPError
            where !fallbackAttempted.contains(itemID) && Self.shouldRetryWithFallback(error.message)
        {
            fallbackAttempted.insert(itemID)
            return try await downloadPhase(
                itemID: itemID, url: url,
                extraArguments: arguments + ["--extractor-args", "youtube:player_client=ios"],
                planned: planned,
            )
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
        items[index].resolution = metadata.resolutionLabel
        items[index].totalBytes = metadata.filesizeApprox
        items[index].thumbnailURL = metadata.thumbnail.flatMap(URL.init(string:))
        saveSoon()
        return metadata
    }

    // MARK: Quality

    /// The quality for this run: the card's pick, else the setting's. With "Ask each
    /// time", the card shows the options and nil comes back: the run ends, freeing
    /// its slot, and `choose` queues the item again.
    private func qualityChoice(for itemID: UUID, metadata: VideoMetadata) -> QualityChoice? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        if let picked = items[index].quality { return picked }
        if let preset = settings.quality.choice { return preset }

        let options = QualitySelection.options(from: metadata.formats ?? [], format: settings.format)
        guard options.count > 1, let first = options.first else {
            return options.first?.choice ?? .video(maxHeight: nil)
        }
        items[index].status = .choosing
        items[index].qualityOptions = options
        items[index].choiceDeadline = Date().addingTimeInterval(Self.choiceWait)
        saveSoon()
        // Unanswered, the first option (the best the format setting allows) starts.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.choiceWait))
            guard let self, items.first(where: { $0.id == itemID })?.status == .choosing else { return }
            choose(id: itemID, choice: first.choice)
        }
        return nil
    }

    static let choiceWait: TimeInterval = 10

    /// Starts a card that is waiting for its quality.
    func choose(id: UUID, choice: QualityChoice) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .choosing else { return }
        items[index].quality = choice
        items[index].qualityOptions = nil
        items[index].choiceDeadline = nil
        items[index].status = .queued
        saveSoon()
        pump()
    }

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
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        items[index].status = .downloading
        let directory = settings.downloadDirectory.appendingPathComponent("Danny", isDirectory: true)
        var finalPath: String?
        var progress = DownloadProgress(planned: planned)
        for try await event in client.downloadStream(
            url: url, into: directory, binaries: binaries, extraArguments: extraArguments,
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
            }
        }
        return finalPath
    }

    private static func shouldRetryWithFallback(_ message: String) -> Bool {
        let lowered = message.lowercased()
        return lowered.contains("403")
            || lowered.contains("confirm you")
            || lowered.contains("sign in to confirm")
    }

    private static func hinted(_ message: String, url _: URL) -> String {
        // The card offers Sign In for these; an update doesn't help.
        if DownloadItem.asksForSignIn(message) { return message }
        let lowered = message.lowercased()
        if lowered.contains("403") {
            return message + "\nThis usually means yt-dlp needs an update: run `brew upgrade yt-dlp` and retry."
        }
        return message
    }

    func toolVersions() async -> String {
        async let ytdlpVersion = client.version(binaries: binaries)
        let ffmpegInstalled = binaries.ffmpegDirectory != nil
        let ytdlpText = await (ytdlpVersion) ?? "not found"
        return "yt-dlp \(ytdlpText) · ffmpeg \(ffmpegInstalled ? "found" : "missing")"
    }

    private func fail(itemID: UUID, message: String) {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        items[index].status = .failed
        items[index].errorMessage = message
        items[index].speedBytesPerSecond = nil
        lastFailureMessage = message
        saveSoon()
    }

    private func saveSoon() {
        guard !isSampleQueue else { return }
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
