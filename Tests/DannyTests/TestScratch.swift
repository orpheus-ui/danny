import Foundation

/// Temporary folders and settings for one test, removed when the suite instance
/// holding this goes away, so test runs leave nothing in the temporary directory
/// or ~/Library/Preferences. Swift Testing makes a suite instance per test.
final class TestScratch {
    private var folders: [URL] = []
    private var suites: [String] = []

    /// A new folder path (`DannyTests-<uuid>`) in the temporary directory, not yet created.
    func folder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DannyTests-\(UUID().uuidString)")
        folders.append(url)
        return url
    }

    /// Empty settings of their own, never the app's.
    func defaults() -> UserDefaults {
        let name = "DannyTests-\(UUID().uuidString)"
        suites.append(name)
        // shortcut: force-unwrapped; suiteName is only nil for the app's own bundle id.
        return UserDefaults(suiteName: name)!
    }

    deinit {
        for url in folders {
            try? FileManager.default.removeItem(at: url)
        }
        // Removing a domain empties it but leaves its file behind.
        let preferences = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Preferences")
        for name in suites {
            UserDefaults().removePersistentDomain(forName: name)
            try? FileManager.default.removeItem(at: preferences.appendingPathComponent("\(name).plist"))
        }
    }
}
