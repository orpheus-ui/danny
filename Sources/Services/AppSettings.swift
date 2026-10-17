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
        static let clipboard = "clipboardLinks"
        static let maxConcurrent = "maxConcurrentDownloads"
        static let browserConsent = "browserConsentGiven"
        static let quality = "quality"
        static let format = "format"
        static let keepsEngineCurrent = "keepsEngineCurrent"
        static let existingFiles = "existingFiles"
        static let filenameTemplate = "filenameTemplate"
        static let folderPerSite = "folderPerSite"
    }

    var downloadDirectory: URL {
        didSet { defaults.set(downloadDirectory.path, forKey: Key.downloadDirectory) }
    }

    /// What happens to a link copied in another app.
    var clipboard: ClipboardPolicy {
        didSet { defaults.set(clipboard.rawValue, forKey: Key.clipboard) }
    }

    var maxConcurrentDownloads: Int {
        didSet { defaults.set(maxConcurrentDownloads, forKey: Key.maxConcurrent) }
    }

    var browserConsentGiven: Bool {
        didSet { defaults.set(browserConsentGiven, forKey: Key.browserConsent) }
    }

    var quality: QualityPreference {
        didSet { defaults.set(quality.rawValue, forKey: Key.quality) }
    }

    var format: FormatPreference {
        didSet { defaults.set(format.rawValue, forKey: Key.format) }
    }

    /// Fetch the latest yt-dlp each time Danny opens.
    var keepsEngineCurrent: Bool {
        didSet { defaults.set(keepsEngineCurrent, forKey: Key.keepsEngineCurrent) }
    }

    /// When the video is already in the folder.
    var existingFiles: ExistingFilePolicy {
        didSet { defaults.set(existingFiles.rawValue, forKey: Key.existingFiles) }
    }

    /// How downloaded files are named.
    var filenameTemplate: FilenameTemplate {
        didSet { defaults.set(filenameTemplate.rawValue, forKey: Key.filenameTemplate) }
    }

    /// Save into a folder per site (`<download folder>/youtube.com/…`).
    var folderPerSite: Bool {
        didSet { defaults.set(folderPerSite, forKey: Key.folderPerSite) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        quality = defaults.string(forKey: Key.quality).flatMap(QualityPreference.init(rawValue:)) ?? .best
        format = defaults.string(forKey: Key.format).flatMap(FormatPreference.init(rawValue:)) ?? .compatible
        existingFiles = defaults.string(forKey: Key.existingFiles).flatMap(ExistingFilePolicy.init(rawValue:)) ?? .ask
        clipboard = defaults.string(forKey: Key.clipboard).flatMap(ClipboardPolicy.init(rawValue:)) ?? .ask
        filenameTemplate = defaults.string(forKey: Key.filenameTemplate).flatMap(FilenameTemplate.init(rawValue:))
            ?? .title
        folderPerSite = defaults.bool(forKey: Key.folderPerSite)
        self.defaults = defaults
        let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let fallback = downloads.appendingPathComponent("Danny", isDirectory: true)
        if let stored = defaults.string(forKey: Key.downloadDirectory) {
            downloadDirectory = URL(fileURLWithPath: stored, isDirectory: true)
        } else {
            downloadDirectory = fallback
        }
        maxConcurrentDownloads = defaults.object(forKey: Key.maxConcurrent) as? Int ?? 3
        browserConsentGiven = defaults.bool(forKey: Key.browserConsent)
        keepsEngineCurrent = defaults.object(forKey: Key.keepsEngineCurrent) as? Bool ?? true
    }
}
