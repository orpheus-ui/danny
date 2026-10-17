import Foundation

// MARK: - Quality pick

extension DownloadManager {
    /// The quality for this run: the card's pick, else the setting's. With "Ask each
    /// time", the card shows the options and nil comes back: the run ends, freeing
    /// its slot, and `choose` queues the item again.
    func qualityChoice(for itemID: UUID, metadata: VideoMetadata) -> QualityChoice? {
        guard let item = items.first(where: { $0.id == itemID }) else { return nil }
        if let picked = item.quality { return picked }
        if let preset = settings.quality.choice { return preset }

        let options = QualitySelection.options(from: metadata.formats ?? [], format: settings.format)
        guard options.count > 1, let first = options.first else {
            return options.first?.choice ?? .video(maxHeight: nil)
        }
        let deadline = Date().addingTimeInterval(Self.choiceWait)
        updateItem(itemID) {
            $0.status = .choosing
            $0.qualityOptions = options
            $0.choiceDeadline = deadline
        }
        saveSoon()
        // Unanswered, the first option (the best the format setting allows) starts.
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.choiceWait))
            // Only this prompt's timer: a retried card asks again with a new deadline.
            guard let self, let item = items.first(where: { $0.id == itemID }),
                  item.status == .choosing, item.choiceDeadline == deadline else { return }
            choose(id: itemID, choice: first.choice)
        }
        return nil
    }

    static let choiceWait: TimeInterval = 10

    /// Starts a card that is waiting for its quality.
    func choose(id: UUID, choice: QualityChoice) {
        guard items.contains(where: { $0.id == id && $0.status == .choosing }) else { return }
        updateItem(id) {
            $0.quality = choice
            $0.qualityOptions = nil
            $0.choiceDeadline = nil
            $0.status = .queued
        }
        saveSoon()
        pump()
    }
}
