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
        static let downloadsOnlyOnWiFi = "downloadsOnlyOnWiFi"
        static let speedMode = "speedMode"
        static let balancedLimit = "balancedLimit"
        static let backgroundLimit = "backgroundLimit"
        /// Before speed modes: bytes per second, 0 for none.
        static let legacySpeedLimit = "speedLimit"
        static let menuBarItem = "menuBarItem"
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

    /// Queued downloads wait while the path is cellular or a hotspot.
    var downloadsOnlyOnWiFi: Bool {
        didSet { defaults.set(downloadsOnlyOnWiFi, forKey: Key.downloadsOnlyOnWiFi) }
    }

    /// Applies to downloads that start after it changes; one already running keeps its limit.
    var speedMode: SpeedMode {
        didSet { defaults.set(speedMode.rawValue, forKey: Key.speedMode) }
    }

    /// Balanced's and Background's top speed per download, in bytes per second.
    var balancedLimit: Int {
        didSet {
            let clamped = Self.clamped(balancedLimit)
            if clamped != balancedLimit { balancedLimit = clamped }
            defaults.set(clamped, forKey: Key.balancedLimit)
        }
    }

    var backgroundLimit: Int {
        didSet {
            let clamped = Self.clamped(backgroundLimit)
            if clamped != backgroundLimit { backgroundLimit = clamped }
            defaults.set(clamped, forKey: Key.backgroundLimit)
        }
    }

    /// The current mode's top speed per download in bytes per second; 0 is no limit.
    var speedLimit: Int { limit(for: speedMode) }

    func limit(for mode: SpeedMode) -> Int {
        switch mode {
        case .full: 0
        case .balanced: balancedLimit
        case .background: backgroundLimit
        }
    }

    /// "Balanced · 5 MB/s": the name with what it does.
    func title(for mode: SpeedMode) -> String {
        mode == .full ? mode.label : "\(mode.label) · \(Format.limit(limit(for: mode)))"
    }

    /// Speed modes replaced a list of fixed limits: no limit becomes Full Speed, any other
    /// value becomes Balanced's limit, so the same speed stays in force.
    static func migrateSpeedLimit(in defaults: UserDefaults) {
        guard defaults.object(forKey: Key.speedMode) == nil,
              let legacy = defaults.object(forKey: Key.legacySpeedLimit) as? Int else { return }
        if legacy > 0 {
            defaults.set(SpeedMode.balanced.rawValue, forKey: Key.speedMode)
            defaults.set(legacy, forKey: Key.balancedLimit)
        }
        defaults.removeObject(forKey: Key.legacySpeedLimit)
    }

    /// Show overall progress and Paste to Download in the menu bar.
    var menuBarItem: Bool {
        didSet { defaults.set(menuBarItem, forKey: Key.menuBarItem) }
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
        downloadsOnlyOnWiFi = defaults.bool(forKey: Key.downloadsOnlyOnWiFi)
        Self.migrateSpeedLimit(in: defaults)
        speedMode = defaults.string(forKey: Key.speedMode).flatMap(SpeedMode.init(rawValue:)) ?? .full
        balancedLimit = Self.storedLimit(Key.balancedLimit, for: .balanced, in: defaults)
        backgroundLimit = Self.storedLimit(Key.backgroundLimit, for: .background, in: defaults)
        menuBarItem = defaults.bool(forKey: Key.menuBarItem)
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

    private static func storedLimit(_ key: String, for mode: SpeedMode, in defaults: UserDefaults) -> Int {
        let stored = defaults.object(forKey: key) as? Int ?? mode.defaultLimit
        return clamped(stored)
    }

    private static func clamped(_ limit: Int) -> Int {
        min(max(limit, SpeedMode.limitRange.lowerBound), SpeedMode.limitRange.upperBound)
    }
}
