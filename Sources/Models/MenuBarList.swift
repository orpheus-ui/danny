import Foundation

/// What the menu-bar popover lists: the downloads running or waiting (a few of them),
/// the last finished files, and the one-line headline.
struct MenuBarList: Equatable {
    struct Active: Identifiable, Equatable {
        let id: UUID
        let title: String
        let thumbnailURL: URL?
        /// Nil until the item knows its size.
        let fraction: Double?
        let speed: Double?
        let remaining: TimeInterval?

        /// "59% · 2 MBps · 1 min left", with what isn't known left out.
        var detail: String {
            [Format.percent(fraction), Format.speed(speed), Format.remaining(remaining)].compactMap(\.self)
                .joined(separator: " · ")
        }

        /// "Title, 59 percent, 2 megabytes per second".
        var spokenLabel: String {
            let percent = fraction.map { "\(Int(($0 * 100).rounded())) percent" }
            let rate = speed.flatMap { $0 > 0 ? Self.spoken(speed: $0) : nil }
            return [title, percent, rate].compactMap(\.self).joined(separator: ", ")
        }

        private static func spoken(speed: Double) -> String {
            if speed >= 1_000_000 { return "\(Int((speed / 1_000_000).rounded())) megabytes per second" }
            if speed >= 1000 { return "\(Int((speed / 1000).rounded())) kilobytes per second" }
            return "\(Int(speed)) bytes per second"
        }
    }

    struct Finished: Identifiable, Equatable {
        let id: UUID
        let title: String
        let thumbnailURL: URL?
        let fileURL: URL
        let finishedAt: Date
    }

    static let maxActive = 4
    static let maxFinished = 3
    /// Newest-added items whose files are dated; a long download can finish after later ones.
    static let finishedCandidates = 8

    let active: [Active]
    /// Active items beyond `maxActive`.
    let more: Int
    let downloading: Int
    let paused: Int
    /// All running downloads together; nil when none reports a speed.
    let speed: Double?
    let finished: [Finished]

    /// `finishedAt` says when a finished item's file landed; it is asked only for the few shown.
    init(items: [DownloadItem], finishedAt: (DownloadItem) -> Date) {
        let counted = items.filter(OverallProgress.counts).sorted { $0.status < $1.status }
        active = counted.prefix(Self.maxActive).map(Self.row)
        more = max(0, counted.count - Self.maxActive)
        let running = items.filter { $0.status == .downloading }
        downloading = running.count
        paused = items.count { $0.status == .paused }
        let total = running.reduce(0) { $0 + ($1.speedBytesPerSecond ?? 0) }
        speed = total > 0 ? total : nil
        finished = items.filter { $0.status == .finished && $0.fileURL != nil }
            .sorted { $0.addedAt > $1.addedAt }.prefix(Self.finishedCandidates)
            .map { Finished(
                id: $0.id,
                title: $0.title,
                thumbnailURL: $0.thumbnailURL,
                fileURL: $0.fileURL!,
                finishedAt: finishedAt($0),
            ) }
            .sorted { $0.finishedAt > $1.finishedAt }.prefix(Self.maxFinished).map(\.self)
    }

    private static func row(_ item: DownloadItem) -> Active {
        var remaining: TimeInterval?
        if let total = item.totalBytes, let done = item.downloadedBytes, let speed = item.speedBytesPerSecond,
           speed > 0
        {
            remaining = Double(max(0, total - done)) / speed
        }
        return Active(
            id: item.id, title: item.title, thumbnailURL: item.thumbnailURL, fraction: item.fractionCompleted,
            speed: item.speedBytesPerSecond, remaining: remaining,
        )
    }

    /// "2 downloading · 4 MBps", "3 waiting", or "Nothing downloading".
    var headline: String {
        if downloading > 0 {
            return ["\(downloading) downloading", Format.speed(speed)].compactMap(\.self).joined(separator: " · ")
        }
        let waiting = active.count + more
        if waiting > 0 { return "\(waiting) waiting" }
        return paused > 0 ? "\(paused) paused" : "Nothing downloading"
    }

    /// "Just now", "2 min ago", "3 h ago", "4 d ago". Worked out when the popover opens.
    static func age(of date: Date, now: Date) -> String {
        let seconds = max(0, now.timeIntervalSince(date))
        if seconds < 60 { return "Just now" }
        if seconds < 3600 { return "\(Int(seconds / 60)) min ago" }
        if seconds < 86400 { return "\(Int(seconds / 3600)) h ago" }
        return "\(Int(seconds / 86400)) d ago"
    }
}
