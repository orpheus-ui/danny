import Foundation

/// When the light passes through the progress bars: `duration` out of every
/// `period` seconds, on the wall clock, so every bar passes at the same moment.
enum ProgressSweep {
    static let duration: TimeInterval = 2.4
    static let period: TimeInterval = 7

    /// Seconds from `time` until the next pass starts (0 while one is under way).
    static func untilNextPass(at time: TimeInterval) -> TimeInterval {
        let phase = time.truncatingRemainder(dividingBy: period)
        return phase < duration ? 0 : period - phase
    }
}
