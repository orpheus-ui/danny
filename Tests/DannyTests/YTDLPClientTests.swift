@testable import Danny
import Testing

struct YTDLPClientTests {
    @Test func `parses progress line`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|1048576|4194304|2.00MiB/s"))
        guard case let .progress(downloaded, total, speed) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(downloaded == 1_048_576)
        #expect(total == 4_194_304)
        #expect(speed == 2_097_152.0)
    }

    @Test func `unknown total is nil`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|500|NA|Unknown"))
        guard case let .progress(_, total, speed) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(total == nil)
        #expect(speed == nil)
    }

    @Test(arguments: ["[download] 5.0% of 10MiB", "@P|1|2", ""])
    func `ignores non progress lines`(line: String) {
        #expect(YTDLPClient.parseProgressLine(line) == nil)
    }

    @Test(arguments: [
        ("1.5KiB/s", 1536.0),
        ("3MiB/s", 3_145_728.0),
        ("2GiB/s", 2_147_483_648.0),
        ("800kB/s", 800_000.0),
        ("12B/s", 12.0),
    ])
    func `parses speed units`(raw: String, expected: Double) {
        #expect(YTDLPClient.parseSpeed(raw) == expected)
    }

    @Test func `rejects speed without number`() {
        #expect(YTDLPClient.parseSpeed("Unknown B/s") == nil)
    }
}
