import SwiftUI

/// How a progress bar's fill moves to a new width: over `duration`, on the same curve
/// as SwiftUI's `.easeOut`, but drawn at most 30 times a second (ADR-008). SwiftUI's
/// own animation redraws the window on every display frame.
struct FillEase {
    static let duration: TimeInterval = 0.45
    /// Frames fall on one 30 fps grid of the shared clock, so bars easing together
    /// redraw in the same frames.
    static let frame: TimeInterval = 1.0 / 30

    private(set) var from: CGFloat = 0
    private(set) var to: CGFloat = 0
    private(set) var start = Date.distantPast
    private var placed = false

    func width(at date: Date) -> CGFloat {
        let progress = min(1, max(0, date.timeIntervalSince(start) / Self.duration))
        return from + (to - from) * UnitCurve.easeOut.value(at: progress)
    }

    /// Eases from where the fill is now to `width`. The first width is taken as it
    /// is, as a bar that appears doesn't ease in.
    mutating func move(to width: CGFloat, at now: Date) {
        guard placed else {
            (from, to, placed) = (width, width, true)
            return
        }
        guard width != to else { return }
        from = self.width(at: now)
        to = width
        start = now
    }

    /// The ease's frames, ending with the first one at or after its end. Once it has
    /// ended they are all past, so nothing redraws a bar at rest.
    var frames: [Date] {
        let end = start.timeIntervalSinceReferenceDate + Self.duration
        let first = (start.timeIntervalSinceReferenceDate / Self.frame).rounded(.up) * Self.frame
        return stride(from: first, to: end + Self.frame, by: Self.frame)
            .map { Date(timeIntervalSinceReferenceDate: $0) }
    }

    /// The ease's frames for a `TimelineView`.
    struct Schedule: TimelineSchedule {
        let frames: [Date]

        func entries(from _: Date, mode _: TimelineScheduleMode) -> [Date] { frames }
    }
}
