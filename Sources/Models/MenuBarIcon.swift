import CoreGraphics
import Foundation

/// What the menu-bar icon shows while something downloads: the mark filling from the
/// bottom as overall progress grows, and the percentage beside it. Nil is idle.
struct MenuBarIcon: Equatable {
    /// Nil until a download knows its size: the faded mark with no fill and no number.
    let percent: Int?

    init(_ progress: OverallProgress) {
        percent = progress.fraction.map { Int((min(1, max(0, $0)) * 100).rounded(.down)) }
    }

    /// The part of `bounds` the filled mark is drawn in: its bottom `percent` of the height.
    /// `bounds` has its origin at the lower left, as in an AppKit drawing handler.
    static func fillRect(percent: Int?, in bounds: CGRect) -> CGRect {
        let fraction = Double(min(100, max(0, percent ?? 0))) / 100
        return CGRect(x: bounds.minX, y: bounds.minY, width: bounds.width, height: bounds.height * fraction)
    }
}

/// How the downloading icon is coloured. The fill is the brand purple, lighter on a
/// dark menu bar and deeper on a light one; the label colour while the menu is open,
/// so it doesn't clash with the highlight. The unfilled base is always the label colour.
struct MenuBarStyle: Equatable {
    enum Fill: Equatable {
        case label, brandLight, brandDeep
    }

    static let baseAlpha = 0.5

    let fill: Fill

    init(isDark: Bool, menuOpen: Bool) {
        fill = menuOpen ? .label : isDark ? .brandLight : .brandDeep
    }
}

enum MenuBarVisibility {
    /// The menu-bar item shows when Settings turn it on, and in a `-sample-queue` launch
    /// (debug builds), which never writes the setting.
    static func isShown(setting: Bool, arguments: [String] = ProcessInfo.processInfo.arguments) -> Bool {
        #if DEBUG
            setting || arguments.contains("-sample-queue")
        #else
            setting
        #endif
    }
}
