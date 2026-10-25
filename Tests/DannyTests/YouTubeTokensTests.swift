@testable import Danny
import Foundation
import Testing

@MainActor
struct YouTubeTokensTests {
    private let cookies = ["--cookies", "/tmp/c.txt"]

    /// Counts mints and hands out numbered tokens that last `lifetime`.
    private final class FakeMint {
        var mints = 0
        let lifetime: TimeInterval

        init(lifetime: TimeInterval = 3600) { self.lifetime = lifetime }

        func tokens() -> YouTubeTokens {
            YouTubeTokens { [self] _ in
                mints += 1
                return YouTubeTokens.Token(value: "t\(mints)", expires: .now + lifetime)
            }
        }
    }

    @Test func `reads the video ID from every YouTube link form`() throws {
        let links = [
            "https://www.youtube.com/watch?v=aqz-KE-bpKQ&t=10",
            "https://youtu.be/aqz-KE-bpKQ?si=x",
            "https://m.youtube.com/shorts/aqz-KE-bpKQ",
            "https://www.youtube.com/live/aqz-KE-bpKQ",
            "https://www.youtube.com/embed/aqz-KE-bpKQ",
        ]
        for link in links {
            #expect(try YouTubeTokens.videoID(in: #require(URL(string: link))) == "aqz-KE-bpKQ", "\(link)")
        }
    }

    @Test func `finds no video ID in other links`() throws {
        let links = [
            "https://www.youtube.com/playlist?list=PL123",
            "https://www.youtube.com/watch?v=short",
            "https://vimeo.com/watch?v=aqz-KE-bpKQ",
        ]
        for link in links {
            #expect(try YouTubeTokens.videoID(in: #require(URL(string: link))) == nil, "\(link)")
        }
    }

    @Test func `adds web_creator and the token when no YouTube clients are set`() {
        #expect(YouTubeTokens.adding("T", to: cookies) == cookies + [
            "--extractor-args", "youtube:player_client=default,web_creator;po_token=web_creator.gvs+T",
        ])
    }

    /// yt-dlp keeps only the last `youtube:` extractor-args, so a second one would drop
    /// the retry's clients.
    @Test func `joins the retry's YouTube clients`() {
        let retry = cookies + DownloadManager.fallbackArguments(signedIn: true)
        #expect(YouTubeTokens.adding("T", to: retry) == cookies + [
            "--extractor-args", "youtube:player_client=web_creator,tv,mweb;po_token=web_creator.gvs+T",
        ])
    }

    @Test func `leaves signed-out and non-YouTube runs alone`() async throws {
        let fake = FakeMint()
        let tokens = fake.tokens()
        let watch = try #require(URL(string: "https://www.youtube.com/watch?v=aqz-KE-bpKQ"))
        let vimeo = try #require(URL(string: "https://vimeo.com/1"))
        #expect(await tokens.arguments(["-f", "best"], for: watch) == ["-f", "best"])
        #expect(await tokens.arguments(cookies, for: vimeo) == cookies)
        #expect(fake.mints == 0)
    }

    @Test func `mints once per video while the token lasts`() async throws {
        let fake = FakeMint()
        let tokens = fake.tokens()
        let watch = try #require(URL(string: "https://www.youtube.com/watch?v=aqz-KE-bpKQ"))
        let first = await tokens.arguments(cookies, for: watch)
        let second = await tokens.arguments(cookies, for: watch)
        #expect(first == second)
        #expect(first.last?.hasSuffix("po_token=web_creator.gvs+t1") == true)
        #expect(fake.mints == 1)
    }

    @Test func `mints again once the token expires`() async {
        let fake = FakeMint(lifetime: 60)
        let tokens = fake.tokens()
        #expect(await tokens.token(for: "aqz-KE-bpKQ", session: "a") == "t1")
        #expect(await tokens.token(for: "aqz-KE-bpKQ", session: "a", now: .now + 61) == "t2")
    }

    /// A token may be bound to the account, and the next run may be another account's.
    @Test func `mints again for another run's session`() async {
        let fake = FakeMint()
        let tokens = fake.tokens()
        #expect(await tokens.token(for: "aqz-KE-bpKQ", session: "/tmp/a.txt") == "t1")
        #expect(await tokens.token(for: "aqz-KE-bpKQ", session: "/tmp/b.txt") == "t2")
    }

    @Test func `runs on without a token when minting fails`() async throws {
        let tokens = YouTubeTokens { _ in nil }
        let watch = try #require(URL(string: "https://www.youtube.com/watch?v=aqz-KE-bpKQ"))
        #expect(await tokens.arguments(cookies, for: watch) == cookies)
    }
}
