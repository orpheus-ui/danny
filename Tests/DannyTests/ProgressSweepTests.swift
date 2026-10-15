@testable import Danny
import Testing

struct ProgressSweepTests {
    @Test(arguments: [0.0, 1.0, 2.5, 3.0, 6.9, 700_000_000.3])
    func `passes start on the shared clock`(time: Double) {
        let next = time + ProgressSweep.untilNextPass(at: time)
        let phase = next.truncatingRemainder(dividingBy: ProgressSweep.period)
        #expect(phase < ProgressSweep.duration + 0.0001)
    }

    @Test
    func `never waits longer than a period`() {
        for time in stride(from: 0.0, to: 14, by: 0.25) {
            #expect(ProgressSweep.untilNextPass(at: time) < ProgressSweep.period)
        }
    }
}
