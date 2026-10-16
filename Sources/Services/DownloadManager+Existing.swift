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
        guard items.contains(where: { $0.id == itemID && $0.status.isActive }) else { return }
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
        }
        saveSoon()
    }

    /// Keeps the file already there: the card ends on it and Finder shows it.
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
        revealInFinder(id: id)
    }
}
