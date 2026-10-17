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

    @Test func `downloads fragmented streams with 8 connections`() {
        let arguments = YTDLPClient.downloadArguments(in: URL(fileURLWithPath: "/tmp"), progressTemplate: "")
        let index = arguments.firstIndex(of: "--concurrent-fragments")
        #expect(index.map { arguments[$0 + 1] } == "8")
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

    @Test func `a signed-out download asked to sign in retries with the session`() {
        let session = ["--cookies", "/tmp/c.txt"]
        let retry = DownloadManager.retryArguments(
            after: "Sign in to confirm you're not a bot", tried: ["-f", "best"], signedIn: session,
        )
        #expect(retry == session + ["-f", "best"] + DownloadManager.fallbackArguments(signedIn: true))
    }

    @Test func `a refused download without a sign-in prompt stays signed out`() {
        let retry = DownloadManager.retryArguments(
            after: "HTTP Error 403: Forbidden", tried: ["-f", "best"], signedIn: ["--cookies", "/tmp/c.txt"],
        )
        #expect(retry == ["-f", "best"] + DownloadManager.fallbackArguments(signedIn: false))
    }

    @Test func `any sign-in prompt to a signed-out download is retried when signed in`() {
        let session = ["--cookies", "/tmp/c.txt"]
        #expect(DownloadManager.shouldRetry(after: "This video requires login required", tried: [], signedIn: session))
        #expect(!DownloadManager.shouldRetry(after: "login required", tried: [], signedIn: []))
        #expect(!DownloadManager.shouldRetry(after: "login required", tried: session, signedIn: session))
    }
}
