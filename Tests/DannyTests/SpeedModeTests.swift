@testable import Danny
import Foundation
import Testing

/// Full Speed, Balanced and Background: the limit each puts on a download, the limits
/// the user sets, and the move from the old list of fixed limits.
@MainActor
struct SpeedModeTests {
    private let scratch = TestScratch()

    @Test func `starts at full speed with the default limits`() {
        let settings = AppSettings(defaults: scratch.defaults())
        #expect(settings.speedMode == .full)
        #expect(settings.balancedLimit == 5_000_000)
        #expect(settings.backgroundLimit == 1_000_000)
    }

    @Test(arguments: [
        (SpeedMode.full, [String]()),
        (.balanced, ["--limit-rate", "5000000"]),
        (.background, ["--limit-rate", "1000000"]),
    ])
    func `each mode maps to a limit rate`(mode: SpeedMode, arguments: [String]) {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.speedMode = mode
        #expect(YTDLPClient.limitRateArguments(settings.speedLimit) == arguments)
    }

    @Test func `edited limits and the mode are remembered`() {
        let defaults = scratch.defaults()
        let settings = AppSettings(defaults: defaults)
        settings.speedMode = .background
        settings.backgroundLimit = 2_500_000
        settings.balancedLimit = 8_000_000

        let reopened = AppSettings(defaults: defaults)
        #expect(reopened.speedMode == .background)
        #expect(reopened.speedLimit == 2_500_000)
        #expect(reopened.limit(for: .balanced) == 8_000_000)
    }

    @Test func `a stored limit outside the range is brought inside it`() {
        let defaults = scratch.defaults()
        defaults.set(10, forKey: "balancedLimit")
        defaults.set(5_000_000_000, forKey: "backgroundLimit")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.balancedLimit == SpeedMode.limitRange.lowerBound)
        #expect(settings.backgroundLimit == SpeedMode.limitRange.upperBound)
    }

    @Test func `a limit set out of range is brought inside it`() {
        let defaults = scratch.defaults()
        let settings = AppSettings(defaults: defaults)
        settings.balancedLimit = 0
        settings.backgroundLimit = Int.max
        #expect(settings.balancedLimit == SpeedMode.limitRange.lowerBound)
        #expect(settings.backgroundLimit == SpeedMode.limitRange.upperBound)
        #expect(AppSettings(defaults: defaults).balancedLimit == SpeedMode.limitRange.lowerBound)
    }

    @Test func `no old limit becomes full speed`() {
        let defaults = scratch.defaults()
        defaults.set(0, forKey: "speedLimit")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.speedMode == .full)
        #expect(settings.balancedLimit == 5_000_000)
        #expect(defaults.object(forKey: "speedLimit") == nil)
    }

    @Test(arguments: [500_000, 1_000_000, 10_000_000])
    func `an old limit becomes balanced at that limit`(limit: Int) {
        let defaults = scratch.defaults()
        defaults.set(limit, forKey: "speedLimit")
        let settings = AppSettings(defaults: defaults)
        #expect(settings.speedMode == .balanced)
        #expect(settings.speedLimit == limit)
        #expect(settings.backgroundLimit == 1_000_000)
    }

    @Test func `the migration runs once and never overrides a chosen mode`() {
        let defaults = scratch.defaults()
        defaults.set(10_000_000, forKey: "speedLimit")
        AppSettings(defaults: defaults).speedMode = .background

        let reopened = AppSettings(defaults: defaults)
        #expect(reopened.speedMode == .background)
        #expect(reopened.balancedLimit == 10_000_000)
    }

    @Test func `menu titles name the mode and its limit`() {
        let settings = AppSettings(defaults: scratch.defaults())
        settings.balancedLimit = 2_500_000
        #expect(SpeedMode.allCases.map(settings.title(for:)) == [
            "Full Speed",
            "Balanced · 2.5 MB/s",
            "Background · 1 MB/s",
        ])
    }
}
