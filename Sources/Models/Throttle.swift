/// Lets an update through at most once per `interval`: the Dock and menu-bar icons'
/// overall progress, and each card's progress line. Appearing and clearing go through
/// at once; a repeat of what is shown never does.
struct Throttle<Value: Equatable> {
    var interval: Duration
    private(set) var shown: Value?
    private var shownAt: ContinuousClock.Instant?

    /// Spelled out: the private properties make the memberwise init private on Swift 6.2.
    init(interval: Duration = .seconds(1)) {
        self.interval = interval
    }

    // shortcut: a dropped update waits for the next progress line rather than a
    // timer, so a stalled download can show a value up to `interval` old.
    mutating func admit(_ value: Value?, at now: ContinuousClock.Instant) -> Bool {
        guard value != shown else { return false }
        if shown != nil, value != nil, let shownAt, now - shownAt < interval { return false }
        shown = value
        shownAt = now
        return true
    }
}
