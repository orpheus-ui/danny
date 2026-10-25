import Foundation

/// Where a run gets a site's cookies; `SiteSessions` in the app, a fake in tests.
@MainActor
protocol CookieSource: AnyObject {
    func cookieFile(for url: URL) async -> TemporaryCookieFile?
    func finish(_ file: TemporaryCookieFile, for url: URL) async
}

extension SiteSessions: CookieSource {}
