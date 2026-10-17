import Foundation

/// Keeps the Mac from sleeping on its own. `DownloadManager` sets `isHeld` while a
/// download runs; tests pass a fake instead of taking a real assertion.
@MainActor
protocol KeepAwake: AnyObject {
    var isHeld: Bool { get set }
}

/// The real one: a power assertion against idle system sleep. The display may still
/// sleep, and a closed lid or the Apple menu still put the Mac to sleep.
@MainActor
final class SystemKeepAwake: KeepAwake {
    private var activity: (any NSObjectProtocol)?

    var isHeld: Bool {
        get { activity != nil }
        set {
            guard newValue != isHeld else { return }
            if newValue {
                activity = ProcessInfo.processInfo.beginActivity(
                    options: .idleSystemSleepDisabled, reason: "Downloading",
                )
            } else if let activity {
                ProcessInfo.processInfo.endActivity(activity)
                self.activity = nil
            }
        }
    }
}
