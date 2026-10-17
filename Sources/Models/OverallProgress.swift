import Foundation

/// One fraction for everything downloading now, for the Dock icon and the menu-bar icon.
struct OverallProgress: Equatable {
    /// Nil while no counted item knows its size yet.
    let fraction: Double?
    let count: Int

    /// Whether the item is running or waiting its turn, rather than finished, failed, paused or waiting on the user.
    static func counts(_ item: DownloadItem) -> Bool {
        item.status.isActive && ![.choosing, .existing, .paused].contains(item.status)
    }

    /// Nil when nothing is running. Finished, failed and paused items don't count, nor
    /// do cards waiting on the user. Byte-weighted when every item knows its size, else
    /// each item weighs the same; an item with no fraction yet counts as 0.
    static func of(_ items: [DownloadItem]) -> OverallProgress? {
        let counted = items.filter(counts)
        guard counted.contains(where: { $0.status != .queued }) else { return nil }
        guard counted.contains(where: { $0.fractionCompleted != nil }) else {
            return OverallProgress(fraction: nil, count: counted.count)
        }
        let sizes = counted.compactMap { $0.totalBytes.flatMap { $0 > 0 ? Double($0) : nil } }
        let weights = sizes.count == counted.count ? sizes : Array(repeating: 1, count: counted.count)
        let done = zip(counted, weights).reduce(0) { $0 + ($1.0.fractionCompleted ?? 0) * $1.1 }
        return OverallProgress(fraction: min(1, done / weights.reduce(0, +)), count: counted.count)
    }
}
