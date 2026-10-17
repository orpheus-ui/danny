import Foundation
import Observation

extension DownloadManager {
    /// "Download only on Wi-Fi" is on and the path is metered: queued items wait
    /// instead of starting. Running ones carry on.
    var waitsForWiFi: Bool {
        settings.downloadsOnlyOnWiFi && network.isMetered
    }

    /// Starts waiting items once the path or the setting lets them. Observation fires
    /// once per registration, so each change registers again.
    func watchNetwork() {
        _ = withObservationTracking { waitsForWiFi } onChange: { [weak self] in
            Task { @MainActor in
                self?.watchNetwork()
                self?.pump()
            }
        }
    }
}
