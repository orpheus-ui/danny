import AppKit
import Foundation
import Observation
import UserNotifications

/// Shows the queue outside the window: overall progress on the Dock icon while
/// anything downloads, and a notification when a download finishes. It reacts to
/// changes of the manager's items only, so nothing runs while the queue is idle.
@MainActor
final class SystemStatus {
    private let manager: DownloadManager
    private let dock: any DockProgress
    private let notifier: any FinishNotifier
    private let now: () -> ContinuousClock.Instant
    private var throttle = DockThrottle()
    private var statuses: [UUID: ItemStatus]

    init(
        manager: DownloadManager, dock: any DockProgress = DockTile(),
        notifier: any FinishNotifier = FinishNotifications(), now: @escaping () -> ContinuousClock.Instant = { .now },
    ) {
        self.manager = manager
        self.dock = dock
        self.notifier = notifier
        self.now = now
        statuses = Self.statuses(of: manager.items)
        observe()
    }

    private static func statuses(of items: [DownloadItem]) -> [UUID: ItemStatus] {
        Dictionary(items.map { ($0.id, $0.status) }) { first, _ in first }
    }

    /// Observation fires once per registration, so each change registers again;
    /// changes between a fire and the next read arrive together.
    private func observe() {
        let items = withObservationTracking { manager.items } onChange: { [weak self] in
            Task { @MainActor in self?.observe() }
        }
        changed(items)
    }

    private func changed(_ items: [DownloadItem]) {
        // A run that ends on its file notifies; keeping a file already there doesn't.
        // Changes can arrive together, so a fast run may skip `.downloading` here.
        for item in items where item.status == .finished {
            if let was = statuses[item.id], was.isActive, was != .existing {
                notifier.notifyFinished(item)
            }
        }
        statuses = Self.statuses(of: items)
        let progress = OverallProgress.of(items)
        if throttle.admit(progress, at: now()) { dock.show(progress) }
    }
}

/// Lets a Dock update through at most once per `interval`. Appearing and clearing go
/// through at once; a repeat of what is shown never does.
struct DockThrottle {
    var interval: Duration = .seconds(1)
    private(set) var shown: OverallProgress?
    private var shownAt: ContinuousClock.Instant?

    // shortcut: a dropped update waits for the next progress line rather than a
    // timer, so a stalled download can show a value up to a second old.
    mutating func admit(_ progress: OverallProgress?, at now: ContinuousClock.Instant) -> Bool {
        guard progress != shown else { return false }
        if shown != nil, progress != nil, let shownAt, now - shownAt < interval { return false }
        shown = progress
        shownAt = now
        return true
    }
}

// MARK: - Dock

@MainActor
protocol DockProgress: AnyObject {
    /// Nil clears the Dock icon back to the plain app icon.
    func show(_ progress: OverallProgress?)
}

/// The real one: a progress bar drawn over the app icon in the Dock.
@MainActor
final class DockTile: DockProgress {
    private var view: DockProgressView?

    func show(_ progress: OverallProgress?) {
        let tile = NSApplication.shared.dockTile
        if let progress {
            let view = view ?? DockProgressView(frame: NSRect(origin: .zero, size: tile.size))
            self.view = view
            view.fraction = progress.fraction
            tile.contentView = view
        } else {
            tile.contentView = nil
            view = nil
        }
        tile.display()
    }
}

/// The app icon with a bar along its bottom; an empty bar while no size is known.
private final class DockProgressView: NSView {
    var fraction: Double?

    override func draw(_: NSRect) {
        NSApplication.shared.applicationIconImage.draw(in: bounds)
        let track = NSRect(
            x: bounds.width * 0.14, y: bounds.height * 0.1, width: bounds.width * 0.72, height: bounds.height * 0.1,
        )
        NSColor.black.withAlphaComponent(0.55).setFill()
        NSBezierPath(roundedRect: track, xRadius: track.height / 2, yRadius: track.height / 2).fill()
        guard let fraction, fraction > 0 else { return }
        var bar = track.insetBy(dx: track.height * 0.15, dy: track.height * 0.15)
        bar.size.width = max(bar.height, bar.width * fraction)
        NSColor.controlAccentColor.setFill()
        NSBezierPath(roundedRect: bar, xRadius: bar.height / 2, yRadius: bar.height / 2).fill()
    }
}

// MARK: - Notifications

@MainActor
protocol FinishNotifier: AnyObject {
    func notifyFinished(_ item: DownloadItem)
}

/// The real one: a notification per finished download, with Show in Finder. Like
/// any app notification it isn't shown while Danny is frontmost, where the card says it.
final class FinishNotifications: NSObject, FinishNotifier, UNUserNotificationCenterDelegate {
    private nonisolated static let category = "finished"
    private nonisolated static let reveal = "reveal"
    private nonisolated static let pathKey = "path"

    /// The delegate is set at launch so an action still works when it relaunches
    /// Danny; permission waits for the first finished download.
    override init() {
        super.init()
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.category,
                actions: [UNNotificationAction(identifier: Self.reveal, title: "Show in Finder")],
                intentIdentifiers: [],
            ),
        ])
    }

    func notifyFinished(_ item: DownloadItem) {
        let content = UNMutableNotificationContent()
        content.title = "Download Finished"
        content.body = item.title
        content.sound = .default
        if let path = item.filePath {
            content.categoryIdentifier = Self.category
            content.userInfo = [Self.pathKey: path]
        }
        let request = UNNotificationRequest(identifier: item.id.uuidString, content: content, trigger: nil)
        Task {
            let center = UNUserNotificationCenter.current()
            // Asks only the first time; later calls return the user's answer.
            guard await (try? center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            try? await center.add(request)
        }
    }

    nonisolated func userNotificationCenter(
        _: UNUserNotificationCenter, didReceive response: UNNotificationResponse,
    ) async {
        guard response.actionIdentifier == Self.reveal,
              let path = response.notification.request.content.userInfo[Self.pathKey] as? String
        else { return }
        await MainActor.run {
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
        }
    }
}
