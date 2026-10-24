import Foundation

// MARK: - Progress

extension DownloadManager {
    /// The item with its run's latest progress, for a view of one card: reading it
    /// observes that run's progress only.
    func withProgress(_ item: DownloadItem) -> DownloadItem {
        liveProgress[item.id]?.applied(to: item) ?? item
    }

    /// Every item with its run's latest progress, for views of the whole queue: reading
    /// it observes every running download's progress.
    var itemsWithProgress: [DownloadItem] { items.map(withProgress) }
}
