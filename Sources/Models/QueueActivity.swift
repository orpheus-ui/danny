import Foundation

/// What the bottom bar's activity pill says. Nil while nothing runs or is paused:
/// the bar is then Sort, Browser and + alone.
enum QueueActivity: Equatable {
    /// Cards running or waiting for a slot, and their combined speed when any reports one.
    case active(count: Int, bytesPerSecond: Double?)
    /// Nothing runs and these cards are paused.
    case paused(count: Int)

    /// Cards waiting on the user's answer (quality, existing file) don't count.
    static func of(_ items: [DownloadItem]) -> QueueActivity? {
        let running = items.filter(\.status.canPause)
        if !running.isEmpty {
            let speeds = running.compactMap(\.speedBytesPerSecond)
            return .active(count: running.count, bytesPerSecond: speeds.isEmpty ? nil : speeds.reduce(0, +))
        }
        let paused = items.count { $0.status == .paused }
        return paused > 0 ? .paused(count: paused) : nil
    }
}
