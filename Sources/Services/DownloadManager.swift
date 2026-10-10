import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class DownloadManager {
    private(set) var items: [DownloadItem] = []
    var sortOrder: SortOrder = .newest
    var query: String = ""
    var pendingManualAdd = false
    private(set) var lastFailureMessage: String?

    let settings: AppSettings

    private let client = YTDLPClient()
    private var binaries: YTDLPClient.Binaries = .missing
    private var runningTasks: [UUID: Task<Void, Never>] = [:]
    private var fallbackAttempted: Set<UUID> = []
    private var saveDebounce: Task<Void, Never>?

    var activeCount: Int {
        items.filter(\.status.isActive).count
    }

    var visibleItems: [DownloadItem] {
        var result = items
        if !query.isEmpty {
            result = result.filter {
                $0.title.localizedCaseInsensitiveContains(query)
                    || $0.host.localizedCaseInsensitiveContains(query)
                    || $0.sourceURL.absoluteString.localizedCaseInsensitiveContains(query)
            }
        }
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
        while activeCount < max(1, settings.maxConcurrentDownloads),
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

        guard binaries.ytdlp.fileExistsAsExecutable else {
            fail(
                itemID: itemID,
                message: """
                yt-dlp not found. Install with `brew install yt-dlp ffmpeg` \
                or run scripts/fetch-dependencies.sh.
                """,
            )
            return
        }

        do {
            let metadata = try await client.probe(url: url, binaries: binaries)
            guard let index = items.firstIndex(where: { $0.id == itemID }),
                  items[index].status == .resolving else { return }
            items[index].title = metadata.title.isEmpty ? items[index].title : metadata.title
            items[index].resolution = metadata.resolutionLabel
            items[index].totalBytes = metadata.filesizeApprox
            items[index].thumbnailURL = metadata.thumbnail.flatMap(URL.init(string:))
            saveSoon()

            let path: String?
            do {
                path = try await downloadPhase(itemID: itemID, url: url, extraArguments: [])
            } catch let error as YTDLPError
                where !fallbackAttempted.contains(itemID) && Self.shouldRetryWithFallback(error.message)
            {
                fallbackAttempted.insert(itemID)
                path = try await downloadPhase(
                    itemID: itemID, url: url,
                    extraArguments: ["--extractor-args", "youtube:player_client=ios"],
                )
            }

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

    private func downloadPhase(itemID: UUID, url: URL, extraArguments: [String]) async throws -> String? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        items[index].status = .downloading
        let directory = settings.downloadDirectory.appendingPathComponent("Danny", isDirectory: true)
        var finalPath: String?
        for try await event in client.downloadStream(
            url: url, into: directory, binaries: binaries, extraArguments: extraArguments,
        ) {
            guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
            switch event {
            case let .progress(downloaded, total, speed):
                if let total {
                    items[index].totalBytes = max(items[index].totalBytes ?? 0, total)
                }
                let denominator = total ?? items[index].totalBytes
                if let denominator, denominator > 0 {
                    items[index].fractionCompleted = Double(downloaded) / Double(denominator)
                } else {
                    items[index].fractionCompleted = nil
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
        let lowered = message.lowercased()
        if lowered.contains("403") || lowered.contains("confirm you") {
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
