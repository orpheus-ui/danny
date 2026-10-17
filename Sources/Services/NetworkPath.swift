import Foundation
import Network
import Observation

/// Whether the Mac's internet path is metered: cellular, or an iPhone's Personal
/// Hotspot, which macOS marks expensive. No path counts too, so leaving a hotspot
/// before Wi-Fi joins doesn't start downloads offline. "Download only on Wi-Fi" waits
/// on it; tests pass a fake.
@MainActor
protocol NetworkPath: AnyObject, Observable {
    var isMetered: Bool { get }
}

/// The real one. `NWPathMonitor` calls back when the path changes, so nothing polls
/// (ADR-008).
@Observable
@MainActor
final class SystemNetworkPath: NetworkPath {
    /// Metered until the first path arrives, a moment after launch, so a restored queue
    /// doesn't start on a hotspot before Danny knows.
    private(set) var isMetered = true
    @ObservationIgnored private let monitor = NWPathMonitor()

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            let metered = Self.isMetered(
                satisfied: path.status == .satisfied, expensive: path.isExpensive,
                cellular: path.usesInterfaceType(.cellular),
            )
            MainActor.assumeIsolated {
                // Paths change often without changing this; only a real change notifies.
                if self?.isMetered != metered { self?.isMetered = metered }
            }
        }
        monitor.start(queue: .main)
    }

    nonisolated static func isMetered(satisfied: Bool, expensive: Bool, cellular: Bool) -> Bool {
        !satisfied || expensive || cellular
    }
}
