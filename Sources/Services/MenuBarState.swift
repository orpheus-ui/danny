import Observation

/// What the menu-bar icon shows. Set only through `SystemStatus`'s Dock throttle, so it
/// changes at most once a second and never while the queue is idle.
@MainActor
@Observable
final class MenuBarState {
    /// Nil when idle. Changes only with the whole percent, so the icon redraws no oftener.
    private(set) var icon: MenuBarIcon?

    func show(_ progress: OverallProgress?) {
        let icon = progress.map(MenuBarIcon.init)
        if icon != self.icon { self.icon = icon }
    }
}
