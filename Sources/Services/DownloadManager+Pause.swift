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
