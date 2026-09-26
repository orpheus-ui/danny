import Foundation

enum ItemStatus: String, Codable, Comparable {
    case queued
    case resolving
    case downloading
    case processing
    case finished
    case failed

    var isActive: Bool {
        switch self {
        case .queued, .resolving, .downloading, .processing: true
        case .finished, .failed: false
        }
    }

    private var rank: Int {
        switch self {
        case .downloading: 0
        case .processing: 1
        case .resolving: 2
        case .queued: 3
        case .failed: 4
        case .finished: 5
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
}
