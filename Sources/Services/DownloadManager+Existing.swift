import AppKit
import Foundation

// MARK: - Already downloaded

extension DownloadManager {
    /// Before a download: extra arguments for where the file goes and what it is called,
    /// or nil when the card now asks what to do with the file already there.
    func existingFileCheck(for itemID: UUID, videoID: String, choice: QualityChoice) async throws -> [String]? {
        guard let item = items.first(where: { $0.id == itemID }) else { return [] }
        let url = item.sourceURL
        guard let existing = existingFile(id: videoID, audio: choice == .audio, url: url)
        else { return outputArguments(for: url) }
        switch item.existingFilePolicy ?? settings.existingFiles {
        case .replace:
            do {
                try moveToTrash(existing)
            } catch {
                throw YTDLPError(message: "Danny couldn't move the old file to the Trash.")
            }
            return outputArguments(for: url)
        case .keepBoth:
            let suffix = ExistingFiles.keepBothSuffix(id: videoID, in: downloadDirectory(for: url))
            return outputArguments(for: url, suffix: suffix)
        case .ask:
            await askAboutExisting(itemID, file: existing)
            return nil
        }
    }

    /// Where a link's file goes: the chosen folder, or the site's folder inside it.
    func downloadDirectory(for url: URL) -> URL {
        SiteFolder.directory(for: url, in: outputDirectory, perSite: settings.folderPerSite)
    }

    /// The `-o` for a link's file, named by the chosen template.
    func outputArguments(for url: URL, suffix: String = "") -> [String] {
        YTDLPClient.outputArguments(
            in: downloadDirectory(for: url),
            template: settings.filenameTemplate,
            suffix: suffix,
        )
    }

    /// Where files of this link's video may be, the one a download goes to first: then the
    /// chosen folder, the link's site folder (whether or not the setting is on now, so
    /// switching it loses nothing) and the Danny folder earlier builds made inside the chosen one.
    func directories(for url: URL) -> [URL] {
        let candidates = [
            downloadDirectory(for: url),
            outputDirectory,
            SiteFolder.directory(for: url, in: outputDirectory, perSite: true),
            outputDirectory.appendingPathComponent("Danny", isDirectory: true),
        ]
        var folders: [URL] = []
        for candidate in candidates where !folders.contains(candidate) {
            folders.append(candidate)
        }
        return folders
    }

    /// The file already downloaded for this video, in any of those folders.
    func existingFile(id: String, audio: Bool, url: URL) -> URL? {
        directories(for: url).lazy.compactMap { ExistingFiles.find(id: id, audio: audio, in: $0) }.first
    }

    /// Puts the card in `.existing`, showing the file found. Like a quality pick, the
    /// run ends here; the user's answer queues the card again.
    func askAboutExisting(_ itemID: UUID, file: URL) async {
        let resolution = await ExistingFiles.resolution(of: file)
        // A cancel during the lookup leaves the card queued, which still counts as active.
        guard !Task.isCancelled, items.contains(where: { $0.id == itemID && $0.status.isActive }) else { return }
        updateItem(itemID) {
            $0.status = .existing
            $0.existingFile = ExistingFile(path: file.path, resolution: resolution)
            $0.fractionCompleted = nil
            $0.speedBytesPerSecond = nil
        }
        saveSoon()
    }

    /// Answers the card's question: download again, replacing the file or beside it.
    func resolveExisting(id: UUID, with policy: ExistingFilePolicy) {
        guard policy != .ask, items.contains(where: { $0.id == id && $0.status == .existing }) else { return }
        updateItem(id) {
            $0.existingFilePolicy = policy
            $0.existingFile = nil
            $0.run = nil
            $0.status = .queued
        }
        saveSoon()
        pump()
    }

    /// Ends a run: the card shows the file made, or asks about the one yt-dlp found
    /// already there, which the check before the download didn't predict.
    func finish(itemID: UUID, path: String?) async {
        guard let item = items.first(where: { $0.id == itemID }) else { return }
        if let skipped = item.existingFile {
            await askAboutExisting(itemID, file: URL(fileURLWithPath: skipped.path))
            return
        }
        updateItem(itemID) {
            $0.status = .finished
            $0.fractionCompleted = 1
            $0.speedBytesPerSecond = nil
            $0.filePath = path
            $0.run = nil
        }
        saveSoon()
    }

    /// Deletes what an unfinished download left: `.part` files and merge parts. The
    /// card's run is stopped first; yt-dlp gets a moment to exit before its files go,
    /// also when a Pause just stopped it and no run is left to wait for.
    func removePartials(of item: DownloadItem, after run: Task<Void, Never>?) {
        guard let videoID = item.videoID else { return }
        let folders = directories(for: item.sourceURL)
        Task {
            await run?.value
            try? await Task.sleep(for: .seconds(1))
            // Another card for the same video (another link to it) may be using them.
            guard !items.contains(where: { $0.videoID == videoID && $0.status.isActive }) else { return }
            for file in folders.flatMap({ ExistingFiles.partials(id: videoID, in: $0) }) {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }

    /// Keeps the file already there: the card ends on it.
    func keepExisting(id: UUID) {
        guard let existing = items.first(where: { $0.id == id && $0.status == .existing })?.existingFile
        else { return }
        updateItem(id) {
            $0.status = .finished
            $0.filePath = existing.path
            $0.resolution = existing.resolution ?? $0.resolution
            $0.fractionCompleted = 1
            $0.existingFile = nil
        }
        saveSoon()
    }
}
