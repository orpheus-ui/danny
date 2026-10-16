import Foundation

// MARK: - Quality pick

extension DownloadManager {
    /// The quality for this run: the card's pick, else the setting's. With "Ask each
    /// time", the card shows the options and nil comes back: the run ends, freeing
    /// its slot, and `choose` queues the item again.
    func qualityChoice(for itemID: UUID, metadata: VideoMetadata) -> QualityChoice? {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return nil }
        if let picked = items[index].quality { return picked }
        if let preset = settings.quality.choice { return preset }

        let options = QualitySelection.options(from: metadata.formats ?? [], format: settings.format)
        guard options.count > 1, let first = options.first else {
            return options.first?.choice ?? .video(maxHeight: nil)
        }
        items[index].status = .choosing
        items[index].qualityOptions = options
        let deadline = Date().addingTimeInterval(Self.choiceWait)
        items[index].choiceDeadline = deadline
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
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .choosing else { return }
        items[index].quality = choice
        items[index].qualityOptions = nil
        items[index].choiceDeadline = nil
        items[index].status = .queued
        saveSoon()
        pump()
    }
}
