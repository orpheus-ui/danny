import AppKit
import Foundation
import Observation

@Observable
@MainActor
final class ClipboardWatcher {
    private var timer: Timer?
    private var lastChangeCount: Int
    private var lastHandledURL: URL?

    let settings: AppSettings
    let manager: DownloadManager

    init(settings: AppSettings, manager: DownloadManager) {
        self.settings = settings
        self.manager = manager
        lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        guard timer == nil else { return }
        let timer = Timer(timeInterval: 0.6, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.poll()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        guard settings.monitorClipboard else { return }
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount
        guard let string = pasteboard.string(forType: .string),
              let url = Self.firstURL(in: string),
              url != lastHandledURL
        else { return }
        lastHandledURL = url
        if manager.add(url: url) {}
    }

    static func firstURL(in text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text))
        for match in matches ?? [] {
            if let url = match.url, let scheme = url.scheme?.lowercased(),
               scheme == "http" || scheme == "https"
            {
                return url
            }
        }
        return nil
    }
}
