import AppKit
import Foundation

// MARK: - Already downloaded

extension DownloadManager {
    /// Before a download: extra arguments for where the file goes, or nil when the
    /// card now asks what to do with the file already in the folder.
    func existingFileCheck(for itemID: UUID, videoID: String, choice: QualityChoice) async throws -> [String]? {
        guard let item = items.first(where: { $0.id == itemID }),
              let existing = ExistingFiles.find(id: videoID, audio: choice == .audio, in: outputDirectory)
        else { return [] }
        switch item.existingFilePolicy ?? settings.existingFiles {
        case .replace:
            do {
                try FileManager.default.trashItem(at: existing, resultingItemURL: nil)
            } catch {
                throw YTDLPError(message: "Danny couldn't move the old file to the Trash.")
            }
            return []
        case .keepBoth:
            let suffix = ExistingFiles.keepBothSuffix(id: videoID, in: outputDirectory)
            return YTDLPClient.outputArguments(in: outputDirectory, suffix: suffix)
        case .ask:
            await askAboutExisting(itemID, file: existing)
            return nil
        }
    }

    /// Puts the card in `.existing`, showing the file found. Like a quality pick, the
    /// run ends here; the user's answer queues the card again.
    func askAboutExisting(_ itemID: UUID, file: URL) async {
        let resolution = await ExistingFiles.resolution(of: file)
        guard let index = items.firstIndex(where: { $0.id == itemID }), items[index].status.isActive else { return }
        items[index].status = .existing
        items[index].existingFile = ExistingFile(path: file.path, resolution: resolution)
        items[index].fractionCompleted = nil
        items[index].speedBytesPerSecond = nil
        saveSoon()
    }

    /// Answers the card's question: download again, replacing the file or beside it.
    func resolveExisting(id: UUID, with policy: ExistingFilePolicy) {
        guard policy != .ask, let index = items.firstIndex(where: { $0.id == id }),
              items[index].status == .existing else { return }
        items[index].existingFilePolicy = policy
        items[index].existingFile = nil
        items[index].status = .queued
        saveSoon()
        pump()
    }

    /// Ends a run: the card shows the file made, or asks about the one yt-dlp found
    /// already there, which the check before the download didn't predict.
    func finish(itemID: UUID, path: String?) async {
        guard let index = items.firstIndex(where: { $0.id == itemID }) else { return }
        if let skipped = items[index].existingFile {
            await askAboutExisting(itemID, file: URL(fileURLWithPath: skipped.path))
            return
        }
        items[index].status = .finished
        items[index].fractionCompleted = 1
        items[index].speedBytesPerSecond = nil
        items[index].filePath = path
        saveSoon()
    }

    /// Keeps the file already there: the card ends on it and Finder shows it.
    func keepExisting(id: UUID) {
        guard let index = items.firstIndex(where: { $0.id == id }), items[index].status == .existing,
              let existing = items[index].existingFile else { return }
        items[index].status = .finished
        items[index].filePath = existing.path
        items[index].resolution = existing.resolution ?? items[index].resolution
        items[index].fractionCompleted = 1
        items[index].existingFile = nil
        saveSoon()
        revealInFinder(id: id)
    }
}
