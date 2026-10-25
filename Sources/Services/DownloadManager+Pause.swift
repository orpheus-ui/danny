import Foundation

// MARK: - Pause and resume

extension DownloadManager {
    /// Stops the card's yt-dlp and keeps its `.part` files: yt-dlp continues them on
    /// the next run, so the card keeps its progress.
    func pause(id: UUID) {
        hold(id)
        saveSoon()
        pump()
    }

    func resume(id: UUID) {
        release(id)
        saveSoon()
        pump()
    }

    func pauseAll() {
        for item in items where item.status.canPause {
            hold(item.id)
        }
        saveSoon()
    }

    func resumeAll() {
        for item in items where item.status == .paused {
            release(item.id)
        }
        saveSoon()
        pump()
    }

    /// The folder, name and format of this run. A resumed card keeps the ones its run
    /// started with: with new settings yt-dlp would start over and leave its `.part`
    /// files behind. Otherwise they come from the current settings, and nil means the
    /// card now waits for an answer.
    func destination(for itemID: UUID, url: URL, metadata: VideoMetadata) async throws -> DownloadRun? {
        if let kept = items.first(where: { $0.id == itemID })?.run { return kept }
        guard let choice = qualityChoice(for: itemID, metadata: metadata) else { return nil }
        let format = QualitySelection.arguments(for: choice, format: settings.format)
        guard let output = try await existingFileCheck(for: itemID, videoID: metadata.id, choice: choice)
        else { return nil }
        let started = DownloadRun(directory: downloadDirectory(for: url), format: format, output: output)
        updateItem(itemID) { $0.run = started }
        saveSoon()
        return started
    }

    private func hold(_ id: UUID) {
        guard items.contains(where: { $0.id == id && $0.status.canPause }) else { return }
        stopRun(id)
        updateItem(id) {
            $0.status = .paused
            $0.speedBytesPerSecond = nil
        }
    }

    private func release(_ id: UUID) {
        guard items.contains(where: { $0.id == id && $0.status == .paused }) else { return }
        updateItem(id) { $0.status = .queued }
    }

    /// The history as it comes back at launch: paused cards stay paused, and cards that
    /// were running when Danny quit are queued to start again.
    static func restored(_ items: [DownloadItem]) -> [DownloadItem] {
        items.map { item in
            guard item.status.isActive, item.status != .paused else { return item }
            var item = item
            item.status = .queued
            item.fractionCompleted = nil
            item.speedBytesPerSecond = nil
            return item
        }
    }
}
