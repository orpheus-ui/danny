import Foundation
import Observation

enum SortOrder: String, CaseIterable, Identifiable {
    case newest
    case oldest
    case name
    case size
    case status

    var id: String { rawValue }

    var label: String {
        switch self {
        case .newest: "Newest First"
        case .oldest: "Oldest First"
        case .name: "Name"
        case .size: "Size"
        case .status: "Status"
        }
    }
}

@Observable
@MainActor
final class AppSettings {
    private enum Key {
        static let downloadDirectory = "downloadDirectory"
        static let monitorClipboard = "monitorClipboard"
        static let maxConcurrent = "maxConcurrentDownloads"
        static let browserConsent = "browserConsentGiven"
    }

    var downloadDirectory: URL {
        didSet { defaults.set(downloadDirectory.path, forKey: Key.downloadDirectory) }
    }

    var monitorClipboard: Bool {
        didSet { defaults.set(monitorClipboard, forKey: Key.monitorClipboard) }
    }

    var maxConcurrentDownloads: Int {
        didSet { defaults.set(maxConcurrentDownloads, forKey: Key.maxConcurrent) }
    }

    var browserConsentGiven: Bool {
        didSet { defaults.set(browserConsentGiven, forKey: Key.browserConsent) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let fallback = downloads.appendingPathComponent("Danny", isDirectory: true)
        if let stored = defaults.string(forKey: Key.downloadDirectory) {
            downloadDirectory = URL(fileURLWithPath: stored, isDirectory: true)
        } else {
            downloadDirectory = fallback
        }
        monitorClipboard = defaults.object(forKey: Key.monitorClipboard) as? Bool ?? false
        maxConcurrentDownloads = defaults.object(forKey: Key.maxConcurrent) as? Int ?? 3
        browserConsentGiven = defaults.bool(forKey: Key.browserConsent)
    }
}
