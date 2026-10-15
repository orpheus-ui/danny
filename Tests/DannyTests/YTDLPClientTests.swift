@testable import Danny
import Foundation
import Testing

struct YTDLPClientTests {
    @Test func `parses progress line`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|1048576|4194304|2.00MiB/s"))
        guard case let .progress(downloaded, total, speed, _) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(downloaded == 1_048_576)
        #expect(total == 4_194_304)
        #expect(speed == 2_097_152.0)
    }

    @Test func `unknown total is nil`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|500|NA|Unknown"))
        guard case let .progress(_, total, speed, _) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(total == nil)
        #expect(speed == nil)
    }

    @Test func `progress names the file being fetched`() throws {
        let event = try #require(YTDLPClient.parseProgressLine("@P|10|20|1.00KiB/s|140"))
        guard case let .progress(_, _, _, file) = event else {
            Issue.record("expected a progress event, got \(event)")
            return
        }
        #expect(file == "140")
    }

    @Test func `the plan lists each requested file`() throws {
        let json = """
        {"id": "x", "title": "t", "requested_formats": [
            {"format_id": "616", "filesize_approx": 900},
            {"format_id": "140", "filesize": 100, "filesize_approx": 120}
        ]}
        """
        let metadata = try JSONDecoder().decode(VideoMetadata.self, from: Data(json.utf8))
        #expect(metadata.plannedFiles == ["616": 900, "140": 100])
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
