import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager {
    private(set) var items: [DownloadItem] = [] {
        didSet {
            updatePauseAll()
            regroup()
        }
    }

    /// Running downloads' progress, by item (`LiveProgress`).
    private(set) var liveProgress: [UUID: LiveProgress] = [:]

    /// What Pause All and Resume All would change. Stored, so the menu and the bottom
    /// bar redraw when these flip, not on every progress line.
    private(set) var canPauseAll = false
    private(set) var canResumeAll = false
    var sortOrder: SortOrder = .newest { didSet { regroup() } }
    var filter = DownloadFilter() { didSet { regroup() } }
    /// The day the list groups against; the window sets it when the calendar day changes.
    var today = Date.now { didSet { regroup() } }
    /// The list as shown: active items, then Today, then Earlier, each in the sort order.
    /// Stored, so reading it neither filters nor sorts: `regroup` redoes it when the
    /// items, the filter, the sort order or the day change.
    private(set) var visibleGroups: [ItemGroup] = []
    /// The list in display order: the sections one after the other.
    private(set) var visibleItems: [DownloadItem] = []
    var pendingManualAdd = false
    private(set) var lastFailureMessage: String?
    /// The last yt-dlp update check, for Settings: nil until one has run.
    private(set) var engineCheck: YTDLPUpdater.Check?
    private(set) var isCheckingEngine = false

    let settings: AppSettings
    /// Signed-in sites; a run passes the link's site cookies to yt-dlp when present.
    var sessions: (any CookieSource)?
    let youTubeTokens = YouTubeTokens()

    let client: any DownloadEngine
    private(set) var binaries: YTDLPClient.Binaries = .missing
    /// The runs in flight; the Mac stays awake while there are any.
    private var runningTasks: [UUID: Task<Void, Never>] = [:] {
        didSet { keepAwake.isHeld = !runningTasks.isEmpty }
    }

    private let keepAwake: any KeepAwake
    /// Whether the path is metered, for "Download only on Wi-Fi".
    let network: any NetworkPath
    private var fallbackAttempted: Set<UUID> = []
    private var saveDebounce: Task<Void, Never>?
    /// `-sample-queue` (one card per state) or `-showcase-queue` (README shots), debug builds: in memory only.
    private var isSampleQueue = false
    /// False in tests: the queue neither loads nor saves the history file.
    private let persists: Bool
    /// Replace's way to drop the old file; tests delete their own file instead.
    var moveToTrash: (URL) throws -> Void = { try FileManager.default.trashItem(at: $0, resultingItemURL: nil) }

    var activeCount: Int { items.count { $0.status.isActive } }

    init(
        settings: AppSettings, client: any DownloadEngine = YTDLPClient(),
        binaries: YTDLPClient.Binaries? = nil, persists: Bool = true, keepAwake: any KeepAwake = SystemKeepAwake(),
        network: any NetworkPath = SystemNetworkPath(),
    ) {
        self.keepAwake = keepAwake
        self.network = network
        self.settings = settings
        self.client = client
        self.persists = persists
        self.binaries = binaries ?? YTDLPClient.locateBinaries()
        #if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-sample-queue") || arguments.contains("-showcase-queue") {
                items = arguments.contains("-showcase-queue") ? DownloadItem.showcase : DownloadItem.samples
                isSampleQueue = true
                updatePauseAll()
                regroup()
                return
            }
        #endif
        items = Self.restored(persists ? PersistenceStore.load() : []).sorted { $0.addedAt > $1.addedAt }
        // `didSet` doesn't run in an initializer.
        updatePauseAll()
        regroup()
        watchNetwork()
        pump()
    }

    func refreshBinaries() {
        binaries = YTDLPClient.locateBinaries()
    }

    @discardableResult
    func add(url: URL) -> Bool {
        let normalized = Self.normalize(url)
        if items.contains(where: { Self.normalize($0.sourceURL) == normalized && $0.status.isActive }) {
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

    /// Stops the card's run where Retry can start it again, and deletes what it downloaded.
    func cancel(id: UUID) {
        let run = stopRun(id)
        guard let item = items.first(where: { $0.id == id }), item.status.isActive else { return }
        updateItem(id) {
            $0.qualityOptions = nil
            $0.choiceDeadline = nil
            $0.existingFile = nil
        }
        fail(itemID: id, message: "Cancelled")
        removePartials(of: item, after: run)
    }

    func retry(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].status = .queued
        items[index].fractionCompleted = nil
        items[index].downloadedBytes = nil
        items[index].speedBytesPerSecond = nil
        items[index].errorMessage = nil
        items[index].filePath = nil
        items[index].run = nil
        saveSoon()
        pump()
    }

    /// Removes the card; an unfinished one takes its partial files with it.
    func remove(id: UUID) {
        let item = items.first { $0.id == id }
        let run = stopRun(id)
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
        guard !isSampleQueue, !waitsForWiFi else { return }
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
        defer { runEnded(itemID) }

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
            guard let metadata = try await probe(itemID: itemID, url: url, signedIn: &cookies),
                  let started = try await destination(
                      for: itemID,
                      url: url,
                      metadata: metadata,
                  ) else { return }

            let path = try await download(
                itemID: itemID, url: url, arguments: cookies + started.format + started.output, signedIn: signedIn,
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

    private func runEnded(_ itemID: UUID) {
        // A stopped run's entry is gone already, and a resumed run may hold it now.
        if !Task.isCancelled { runningTasks[itemID] = nil }
        pump()
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
        // Thrown, not nil: a nil path would mark a stopped card finished.
        let arguments = await youTubeTokens.arguments(extraArguments, for: url)
        try Task.checkCancellation()
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        items[index].status = .downloading
        var finalPath: String?
        var progress = DownloadProgress(planned: planned)
        let live = LiveProgress(.init(fraction: items[index].fractionCompleted, totalBytes: items[index].totalBytes))
        liveProgress[itemID] = live
        var throttle = Throttle<LiveProgress.Line>(interval: LiveProgress.interval)
        var latest = live.line
        // The last line reaches the item; a stopped run's was handed over by `stopRun`.
        defer {
            if liveProgress[itemID] === live {
                live.line = latest
                endLiveProgress(itemID)
            }
        }
        for try await event in client.downloadStream(
            url: url, into: items[index].run?.directory ?? downloadDirectory(for: url), binaries: binaries,
            extraArguments: arguments + YTDLPClient.limitRateArguments(settings.speedLimit),
        ) {
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
            switch event {
            case let .progress(downloaded, total, speed, file):
                latest = LiveProgress.Line(
                    fraction: progress.update(file: file, downloaded: downloaded, total: total),
                    totalBytes: progress.totalBytes ?? latest.totalBytes, speed: speed,
                )
                if throttle.admit(latest, at: .now) {
                    let resized = live.line.totalBytes != latest.totalBytes
                    live.line = latest
                    // Sorted by size, the list follows the sizes as they become known.
                    if resized, sortOrder == .size { regroup() }
                }
            case let .outputFile(path):
                finalPath = path
            case let .alreadyDownloaded(path):
                items[index].existingFile = ExistingFile(path: path)
            }
        }
        // A stopped run's stream just ends; it mustn't mark the card finished.
        try Task.checkCancellation()
        return finalPath
    }

    /// Changes one item in place; how the manager's extensions in other files write.
    func updateItem(_ id: UUID, _ body: (inout DownloadItem) -> Void) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        body(&items[index])
    }

    var outputDirectory: URL { settings.downloadDirectory }

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

// MARK: - Run bookkeeping

/// In this file for the class's private state, outside its body for its length.
extension DownloadManager {
    /// Ends the card's run, if any, and returns it so its files can wait for it to exit.
    @discardableResult
    func stopRun(_ id: UUID) -> Task<Void, Never>? {
        let run = runningTasks.removeValue(forKey: id)
        run?.cancel()
        endLiveProgress(id)
        return run
    }

    /// Hands a run's last progress to its item, which keeps it from here on.
    private func endLiveProgress(_ id: UUID) {
        guard let line = liveProgress.removeValue(forKey: id)?.line else { return }
        updateItem(id) {
            $0.fractionCompleted = line.fraction
            $0.totalBytes = line.totalBytes
        }
    }

    private func regroup() {
        let matching = filter.isEmpty ? items : items.filter(filter.matches)
        let sorted = Self.sorted(matching, by: sortOrder) { withProgress($0).totalBytes }
        visibleGroups = Self.grouped(sorted, now: today)
        visibleItems = visibleGroups.flatMap(\.items)
    }

    private func updatePauseAll() {
        let pausable = items.contains { $0.status.canPause }
        let paused = items.contains { $0.status == .paused }
        if canPauseAll != pausable { canPauseAll = pausable }
        if canResumeAll != paused { canResumeAll = paused }
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
