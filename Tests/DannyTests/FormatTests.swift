@testable import Danny
import Foundation
import Testing

struct FormatTests {
    @Test(arguments: [
        (Int64(2_250_000_000), "2.25 GB"),
        (Int64(12_000_000_000), "12 GB"),
        (Int64(340_000_000), "340 MB"),
        (Int64(52000), "52 KB"),
    ])
    func `formats sizes`(bytes: Int64, expected: String) {
        #expect(Format.size(bytes) == expected)
    }

    @Test(arguments: [nil, Int64(0), Int64(-5)])
    func `no size for unknown or empty`(bytes: Int64?) {
        #expect(Format.size(bytes) == nil)
    }

    @Test(arguments: [
        (80_000_000.0, "80 MBps"),
        (867_000.0, "867 KBps"),
        (300.0, "300 Bps"),
    ])
    func `formats speeds`(bytesPerSecond: Double, expected: String) {
        #expect(Format.speed(bytesPerSecond) == expected)
    }

    @Test func `rounds percent`() {
        #expect(Format.percent(0.536) == "54%")
        #expect(Format.percent(nil) == nil)
    }
}

@MainActor
struct URLHandlingTests {
    @Test func `normalize drops fragment`() throws {
        let url = try #require(URL(string: "https://example.com/watch?v=abc#t=30"))
        #expect(DownloadManager.normalize(url).absoluteString == "https://example.com/watch?v=abc")
    }

    @Test func `finds first web link in clipboard text`() {
        let text = "look at this ftp://nope.example and https://youtu.be/xyz then http://b.example"
        #expect(LinkIntake.link(from: text)?.absoluteString == "https://youtu.be/xyz")
    }

    @Test func `no link in plain text`() {
        #expect(LinkIntake.link(from: "just words") == nil)
    }
}
