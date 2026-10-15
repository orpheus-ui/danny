@testable import Danny
import Foundation
import Testing

struct SignInSiteTests {
    /// 30 days out, whole seconds; cookie lifetimes are capped at about 400 days.
    private let expiry = Int(Date().timeIntervalSince1970) / 60 * 60 + 30 * 86400

    private func cookie(_ name: String, domain: String, httpOnly: Bool = false) -> HTTPCookie {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .name: name, .value: "v", .domain: domain, .path: "/", .secure: "TRUE",
            .expires: Date(timeIntervalSince1970: TimeInterval(expiry)),
        ]
        if httpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
        return HTTPCookie(properties: properties)!
    }

    @Test(arguments: [
        ("https://www.youtube.com/watch?v=1", "youtube"),
        ("https://youtu.be/1", "youtube"),
        ("https://m.youtube.com/shorts/1", "youtube"),
        ("https://www.instagram.com/reel/1", "instagram"),
        ("https://x.com/a/status/1", "x"),
        ("https://vimeo.com/1", nil),
    ] as [(String, String?)])
    func `a link maps to its sign-in site`(link: String, siteID: String?) throws {
        #expect(try SignInSite.site(for: #require(URL(string: link)))?.id == siteID)
    }

    @Test
    func `a failed item asks for sign-in when the site wants it`() throws {
        var item = try DownloadItem(url: #require(URL(string: "https://www.youtube.com/watch?v=1")))
        item.status = .failed
        item.errorMessage = "[youtube] 1: Sign in to confirm you’re not a bot. Use --cookies-from-browser"
        #expect(item.asksForSignIn)
        item.errorMessage = "Unsupported URL"
        #expect(!item.asksForSignIn)
        item.errorMessage = "Sign in to confirm your age"
        item.status = .downloading
        #expect(!item.asksForSignIn)
    }

    @Test(arguments: [
        ("vimeo.com", "vimeo.com", "https://vimeo.com"),
        ("https://www.vimeo.com/log_in", "vimeo.com", "https://www.vimeo.com/log_in"),
        ("open.spotify.com", "open.spotify.com", "https://open.spotify.com"),
    ])
    func `a custom site comes from an address`(text: String, domain: String, login: String) {
        let site = SignInSite.custom(from: text)
        #expect(site?.cookieDomains == [domain])
        #expect(site?.loginURL.absoluteString == login)
        #expect(site?.isCustom == true)
    }

    @Test(arguments: ["", "not a site", "ftp://files.example.com"])
    func `an address that isn't a web site is refused`(text: String) {
        #expect(SignInSite.custom(from: text) == nil)
    }

    @Test
    func `a custom site counts lasting cookies as signed in`() throws {
        let site = try #require(SignInSite.custom(from: "vimeo.com"))
        let lasting = cookie("vuid", domain: ".vimeo.com")
        let sessionOnly = try #require(HTTPCookie(properties: [
            .name: "tmp",
            .value: "v",
            .domain: ".vimeo.com",
            .path: "/",
        ]))
        #expect(site.isSignedIn(with: [lasting]))
        #expect(!site.isSignedIn(with: [sessionOnly]))
        #expect(try SignInSite.site(for: #require(URL(string: "https://player.vimeo.com/1")), in: [site]) == site)
    }

    @Test
    func `a session cookie on the site's domain means signed in`() {
        let youtube = SignInSite.youtube
        #expect(youtube.isSignedIn(with: [cookie("LOGIN_INFO", domain: ".youtube.com")]))
        #expect(!youtube.isSignedIn(with: [cookie("PREF", domain: ".youtube.com")]))
        #expect(!youtube.isSignedIn(with: [cookie("LOGIN_INFO", domain: ".notyoutube.com")]))
    }

    @Test
    func `cookies are written in the Netscape format`() {
        let text = NetscapeCookies.format([
            cookie("LOGIN_INFO", domain: ".youtube.com", httpOnly: true),
            cookie("PREF", domain: "www.youtube.com"),
        ])
        let lines = text.split(separator: "\n").map(String.init)
        #expect(lines[0] == "# Netscape HTTP Cookie File")
        #expect(lines[1] == "#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t\(expiry)\tLOGIN_INFO\tv")
        #expect(lines[2] == "www.youtube.com\tFALSE\t/\tTRUE\t\(expiry)\tPREF\tv")
    }

    @Test
    func `cookies read back match what was written`() {
        let written = [
            cookie("LOGIN_INFO", domain: ".youtube.com", httpOnly: true),
            cookie("PREF", domain: "www.youtube.com"),
        ]
        let read = NetscapeCookies.parse(NetscapeCookies.format(written))
        #expect(read.map(\.name) == ["LOGIN_INFO", "PREF"])
        #expect(read.map(\.domain) == [".youtube.com", "www.youtube.com"])
        #expect(read.map(\.isHTTPOnly) == [true, false])
        #expect(read.allSatisfy { $0.isSecure && $0.expiresDate == Date(timeIntervalSince1970: TimeInterval(expiry)) })
    }
}
