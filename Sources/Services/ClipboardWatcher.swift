import AppKit
import Foundation
import Observation

/// Looks at the clipboard when Danny becomes active, never on a timer (ADR-008):
/// a link copied in another app is there by the time the user switches back.
@Observable
@MainActor
final class ClipboardWatcher {
    /// The copied link waiting for the user's answer, when the setting is Ask.
    var offer: URL?

    private var lastChangeCount: Int
    private var activation: NSObjectProtocol?

    let settings: AppSettings
    let manager: DownloadManager
    private let pasteboard: NSPasteboard

    init(settings: AppSettings, manager: DownloadManager, pasteboard: NSPasteboard = .general) {
        self.settings = settings
        self.manager = manager
        self.pasteboard = pasteboard
        lastChangeCount = pasteboard.changeCount
    }

    func start() {
        guard activation == nil else { return }
        activation = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main,
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.check() }
        }
    }

    func check() {
        guard settings.clipboard != .off, pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let string = pasteboard.string(forType: .string),
              let url = LinkIntake.link(from: string)
        else { return }
        if settings.clipboard == .ask {
            offer = url
        } else {
            manager.add(url: url)
        }
    }

    func acceptOffer() {
        if let offer { manager.add(url: offer) }
        offer = nil
    }

    func dismissOffer() {
        offer = nil
    }

    /// Copies a link from Danny itself, so coming back to Danny doesn't offer it as new.
    func copy(_ url: URL) {
        pasteboard.clearContents()
        pasteboard.setString(url.absoluteString, forType: .string)
        lastChangeCount = pasteboard.changeCount
    }
}
