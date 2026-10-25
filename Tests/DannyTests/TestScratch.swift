import AppKit

/// Temporary folders and settings for one test, removed when the suite instance
/// holding this goes away, so test runs leave nothing in the temporary directory
/// or ~/Library/Preferences, nor pasteboards behind. Swift Testing makes a suite instance per test.
final class TestScratch {
    private var folders: [URL] = []
    private var pasteboards: [NSPasteboard.Name] = []

    /// A new folder path (`DannyTests-<uuid>`) in the temporary directory, not yet created.
    func folder() -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("DannyTests-\(UUID().uuidString)")
        folders.append(url)
        return url
    }

    /// Empty settings of their own, never the app's. A suite named by an absolute
    /// path keeps its plist in a scratch folder: one named by a plain name lands in
    /// ~/Library/Preferences, and cfprefsd writes it back after it's removed.
    func defaults() -> UserDefaults {
        let file = folder().appendingPathComponent("defaults.plist")
        // shortcut: force-unwrapped; suiteName is only nil for the app's own bundle id.
        return UserDefaults(suiteName: file.path)!
    }

    /// A pasteboard of its own, never the general one. Uniquely named pasteboards
    /// outlive the process until released, so it is released with the scratch.
    func pasteboard() -> NSPasteboard {
        let pasteboard = NSPasteboard.withUniqueName()
        pasteboards.append(pasteboard.name)
        return pasteboard
    }

    deinit {
        for url in folders {
            try? FileManager.default.removeItem(at: url)
        }
        for name in pasteboards {
            NSPasteboard(name: name).releaseGlobally()
        }
    }
}
