import Observation

/// A running download's latest progress. It is kept beside `DownloadManager.items`, not
/// in them, so a progress line redraws only its own card; the item takes the last
/// values when the run stops.
@MainActor
@Observable
final class LiveProgress {
    struct Line: Equatable {
        var fraction: Double?
        var totalBytes: Int64?
        var speed: Double?
    }

    /// How often a card's line may change: once a second, like the Dock. Each change
    /// eases the bar for 0.45 s (`FillEase`), so the bar rests between changes.
    static let interval = Duration.seconds(1)

    var line: Line

    init(_ line: Line) {
        self.line = line
    }

    /// The item as shown while it downloads.
    func applied(to item: DownloadItem) -> DownloadItem {
        var item = item
        item.fractionCompleted = line.fraction
        item.totalBytes = line.totalBytes
        item.speedBytesPerSecond = line.speed
        return item
    }
}
