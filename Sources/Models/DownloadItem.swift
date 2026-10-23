import Foundation

enum ItemStatus: String, Codable, Comparable {
    case queued
    case resolving
    /// Waiting for the user to pick a quality on the card.
    case choosing
    /// Waiting for the user: a file of this video is already in the folder.
    case existing
    case downloading
    case processing
    /// Stopped by the user with its partial files kept; Resume continues them.
    case paused
    case finished
    case failed

    var isActive: Bool {
        switch self {
        case .queued, .resolving, .choosing, .existing, .downloading, .processing, .paused: true
        case .finished, .failed: false
        }
    }

    /// Running or waiting for a slot; a card waiting on the user's answer isn't.
    var canPause: Bool {
        [.queued, .resolving, .downloading, .processing].contains(self)
    }

    private var rank: Int {
        switch self {
        case .downloading: 0
        case .processing: 1
        case .choosing, .existing: 2
        case .resolving: 3
        case .queued: 4
        case .paused: 5
        case .failed: 6
        case .finished: 7
        }
    }

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rank < rhs.rank }
}

struct DownloadItem: Identifiable, Codable, Hashable {
    let id: UUID
    var sourceURL: URL
    var title: String
    var host: String
    var resolution: String?
    var totalBytes: Int64?
    var thumbnailURL: URL?
    var status: ItemStatus
    var fractionCompleted: Double?
    var downloadedBytes: Int64?
    var speedBytesPerSecond: Double?
    var filePath: String?
    var errorMessage: String?
    var addedAt: Date
    /// The site's id for the video, from the probe; names its files `… [id].ext`.
    var videoID: String?
    /// The quality picked for this item; nil follows the setting.
    var quality: QualityChoice?
    /// While choosing: the options on the card, and when the default starts.
    var qualityOptions: [QualityOption]?
    var choiceDeadline: Date?
    /// What to do when the file is already there; nil follows the setting.
    var existingFilePolicy: ExistingFilePolicy?
    /// While `.existing`: the file found and its resolution, when known.
    var existingFile: ExistingFile?
    /// Where the download started, kept so a resume continues the same files.
    var run: DownloadRun?

    init(url: URL) {
        id = UUID()
        sourceURL = url
        title = url.absoluteString
        host = url.host ?? url.absoluteString
        resolution = nil
        totalBytes = nil
        thumbnailURL = nil
        status = .queued
        fractionCompleted = nil
        downloadedBytes = nil
        speedBytesPerSecond = nil
        filePath = nil
        errorMessage = nil
        addedAt = Date()
    }

    /// The downloaded file once the item is finished: what Open, Quick Look and the
    /// hover actions use. Nil while downloading or failed.
    var fileURL: URL? {
        guard status == .finished, let filePath else { return nil }
        return URL(fileURLWithPath: filePath)
    }
}

extension [DownloadItem] {
    /// The card an arrow key selects: `step` cards on in display order, stopping at either end.
    /// With no listed selection, ↓ starts at the top and ↑ at the bottom.
    func selection(movingFrom current: UUID?, by step: Int) -> UUID? {
        guard !isEmpty else { return nil }
        guard let index = firstIndex(where: { $0.id == current }) else {
            return step < 0 ? last?.id : first?.id
        }
        return self[Swift.min(Swift.max(index + step, 0), count - 1)].id
    }

    /// The card selected once `id` is removed: the one below it, or above it at the end.
    func selection(afterRemoving id: UUID) -> UUID? {
        guard let index = firstIndex(where: { $0.id == id }) else { return nil }
        if index + 1 < count { return self[index + 1].id }
        return index > 0 ? self[index - 1].id : nil
    }
}

/// What a download does when a file of the same video is already in the folder.
enum ExistingFilePolicy: String, CaseIterable, Identifiable, Codable {
    case ask, replace, keepBoth

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask: "Ask"
        case .replace: "Always Replace"
        case .keepBoth: "Always Keep Both"
        }
    }
}

/// What happens to a link copied in another app.
enum ClipboardPolicy: String, CaseIterable, Identifiable {
    case ask, addAtOnce, off

    var id: String { rawValue }

    var label: String {
        switch self {
        case .ask: "Ask"
        case .addAtOnce: "Add at Once"
        case .off: "Off"
        }
    }
}

/// The destination and format a download started with. Resume reuses them whatever the
/// settings say by then, so yt-dlp continues its `.part` files instead of starting over.
struct DownloadRun: Codable, Hashable {
    var directory: URL
    /// The format selection, and the `-o` (folder, name template, " (2)" suffix).
    var format: [String]
    var output: [String]
}

struct ExistingFile: Codable, Hashable {
    var path: String
    var resolution: String?
}
