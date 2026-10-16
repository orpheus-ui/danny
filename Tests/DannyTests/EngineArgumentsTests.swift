@testable import Danny
import Foundation
import Testing

struct EngineArgumentsTests {
    @Test func `pins yt-dlp to the bundled runtime`() {
        let runtime = URL(fileURLWithPath: "/Applications/Danny.app/Contents/Resources/bin/qjs")
        let binaries = YTDLPClient.Binaries(
            ytdlp: URL(fileURLWithPath: "/bin/yt-dlp"), ffmpegDirectory: nil, jsRuntime: runtime,
        )
        #expect(binaries.runtimeArguments == ["--no-js-runtimes", "--js-runtimes", "quickjs:\(runtime.path)"])
    }

    @Test func `leaves yt-dlp's default without a bundled runtime`() {
        #expect(YTDLPClient.Binaries.missing.runtimeArguments.isEmpty)
    }

    @Test func `signed-in retry asks only for clients that send cookies`() {
        let clients = DownloadManager.fallbackArguments(signedIn: true).last ?? ""
        #expect(clients == "youtube:player_client=tv,mweb")
        #expect(!clients.contains("ios"))
    }

    @Test func `signed-out retry uses the iOS client`() {
        #expect(DownloadManager.fallbackArguments(signedIn: false) == ["--extractor-args", "youtube:player_client=ios"])
    }

    @Test func `goes signed out first on YouTube`() throws {
        let cookies = ["--cookies", "/tmp/c.txt"]
        let watch = try #require(URL(string: "https://www.youtube.com/watch?v=x"))
        let short = try #require(URL(string: "https://youtu.be/x"))
        #expect(DownloadManager.firstTryCookies(for: watch, signedIn: cookies).isEmpty)
        #expect(DownloadManager.firstTryCookies(for: short, signedIn: cookies).isEmpty)
    }

    @Test func `other signed-in sites send their cookies from the start`() throws {
        let cookies = ["--cookies", "/tmp/c.txt"]
        let link = try #require(URL(string: "https://www.instagram.com/reel/x"))
        #expect(DownloadManager.firstTryCookies(for: link, signedIn: cookies) == cookies)
    }
}
