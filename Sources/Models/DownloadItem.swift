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
    /// The file Quick Look shows: the selected item's, when it is listed and finished.
    func previewURL(selection: UUID?) -> URL? {
        first { $0.id == selection }?.fileURL
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

struct ExistingFile: Codable, Hashable {
    var path: String
    var resolution: String?
}
