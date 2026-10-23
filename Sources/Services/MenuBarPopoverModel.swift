import AppKit
import Observation

/// What the popover shows while it is open. It is made when the popover opens and dropped
/// when it closes, so nothing observes the queue in between: the clipboard is read once
/// here, the relative times are worked out against `now`, and the list follows the queue.
@MainActor
@Observable
final class MenuBarPopoverModel {
    private(set) var list: MenuBarList
    /// The link on the clipboard when the popover opened, if any.
    let clipboardLink: URL?
    let now: Date
    @ObservationIgnored private let manager: DownloadManager
    @ObservationIgnored private var finishedDates: [UUID: Date] = [:]

    init(manager: DownloadManager, pasteboard: NSPasteboard = .general, now: Date = .now) {
        self.manager = manager
        self.now = now
        clipboardLink = LinkIntake.pasteboardLink(pasteboard)
        list = MenuBarList(items: [], finishedAt: { _ in now })
        observe()
    }

    private func observe() {
        let items = withObservationTracking { manager.itemsWithProgress } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        list = MenuBarList(items: items, finishedAt: finishedDate)
    }

    /// When the file was written, else when the item was added; read once per item.
    private func finishedDate(_ item: DownloadItem) -> Date {
        if let known = finishedDates[item.id] { return known }
        let modified = item.filePath.flatMap {
            try? FileManager.default.attributesOfItem(atPath: $0)[.modificationDate] as? Date
        }
        let date = modified ?? item.addedAt
        finishedDates[item.id] = date
        return date
    }
}
