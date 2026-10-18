import Foundation

/// How fast downloads may go: flat out, or held to a limit that keeps the connection usable.
enum SpeedMode: String, CaseIterable, Identifiable {
    case full
    case balanced
    case background

    var id: String { rawValue }

    var label: String {
        switch self {
        case .full: "Full Speed"
        case .balanced: "Balanced"
        case .background: "Background"
        }
    }

    /// What Balanced and Background start at, in bytes per second.
    var defaultLimit: Int {
        switch self {
        case .full: 0
        case .balanced: 5_000_000
        case .background: 1_000_000
        }
    }

    /// The limits a mode can be set to, in bytes per second.
    static let limitRange = 500_000 ... 100_000_000
}
