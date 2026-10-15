import Foundation
import Observation
import WebKit

/// A cookie file for one yt-dlp run. yt-dlp's `--cookies` reads a file, so the
/// signed-in site's cookies exist on disk only for the run: in the user's private
/// temporary folder, readable by this user only, removed when the run ends.
nonisolated struct TemporaryCookieFile: Sendable {
    static let prefix = "danny-cookies-"

    let url: URL
    /// What was written, by cookie identity, so only what the run changed goes back.
    let written: [String: Stamp]
    /// The site's sign-out count when written; a sign-out since voids the write-back.
    let generation: Int

    var arguments: [String] { ["--cookies", url.path] }

    /// The parts of a cookie a refresh changes.
    struct Stamp: Equatable {
        let value: String
        let expires: Date?

        init(_ cookie: HTTPCookie) {
            value = cookie.value
            expires = cookie.expiresDate
        }
    }

    static func key(_ cookie: HTTPCookie) -> String {
        [cookie.domain, cookie.path, cookie.name].joined(separator: "\t")
    }

    static func write(_ cookies: [HTTPCookie], generation: Int) -> TemporaryCookieFile? {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(prefix + UUID().uuidString + ".txt")
        // Created new and private in one step (O_EXCL, 0600), before anything is written.
        let descriptor = open(url.path, O_WRONLY | O_CREAT | O_EXCL, 0o600)
        guard descriptor >= 0 else { return nil }
        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        do {
            try handle.write(contentsOf: Data(NetscapeCookies.format(cookies).utf8))
            try handle.close()
        } catch {
            try? FileManager.default.removeItem(at: url)
            return nil
        }
        let written = Dictionary(cookies.map { (key($0), Stamp($0)) }, uniquingKeysWith: { _, last in last })
        return TemporaryCookieFile(url: url, written: written, generation: generation)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }

    /// Files left behind if Danny quit mid-download.
    static func removeLeftovers() {
        let directory = FileManager.default.temporaryDirectory
        let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        for name in names where name.hasPrefix(prefix) {
            try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
        }
    }
}

/// Which sites the user is signed in to in Danny's browser. Sessions stay in
/// WebKit's own store (the default one, shared with Browser Capture, so one sign-in
/// serves both); Danny keeps no copy. Updates come from the store's notifications.
@Observable
@MainActor
final class SiteSessions: NSObject, WKHTTPCookieStoreObserver {
    private(set) var signedIn: Set<String> = []
    /// Built-in sites, then the ones the user added.
    private(set) var sites: [SignInSite] = SignInSite.builtIn

    @ObservationIgnored private let store = WKWebsiteDataStore.default().httpCookieStore
    @ObservationIgnored private var pendingRefresh: Task<Void, Never>?
    /// Sign-outs per site, so a run that started before one doesn't restore its cookies.
    @ObservationIgnored private var signOuts: [String: Int] = [:]

    override init() {
        super.init()
        TemporaryCookieFile.removeLeftovers()
        sites = SignInSite.builtIn + Self.loadCustomSites()
        store.add(self)
        Task { await refresh() }
    }

    func isSignedIn(_ site: SignInSite) -> Bool { signedIn.contains(site.id) }

    func refresh() async {
        let cookies = await store.allCookies()
        signedIn = Set(sites.filter { $0.isSignedIn(with: cookies) }.map(\.id))
    }

    /// The cookies of the link's site, for one yt-dlp run; nil when the user isn't
    /// signed in to it. The caller passes the file to `finish` when the run ends.
    func cookieFile(for url: URL) async -> TemporaryCookieFile? {
        guard let site = site(for: url) else { return nil }
        var file: TemporaryCookieFile?
        await serialized {
            let cookies = await self.store.allCookies().filter { site.owns(cookieDomain: $0.domain) }
            guard site.isSignedIn(with: cookies) else { return }
            file = TemporaryCookieFile.write(cookies, generation: self.signOuts[site.id, default: 0])
        }
        return file
    }

    /// Ends a run: cookies yt-dlp refreshed during it (a new value or a later expiry)
    /// go into the store, so the session stays current; then the file goes. A cookie
    /// goes back only if the store still holds what the run started with, so a
    /// parallel run's or a new sign-in's fresher cookie stays, and nothing goes back
    /// after a sign-out. Runs, write-backs and sign-outs take turns.
    func finish(_ file: TemporaryCookieFile, for url: URL) async {
        defer { file.remove() }
        guard let site = site(for: url),
              let text = try? String(contentsOf: file.url, encoding: .utf8) else { return }
        await serialized {
            guard self.signOuts[site.id, default: 0] == file.generation else { return }
            var current: [String: TemporaryCookieFile.Stamp] = [:]
            for cookie in await self.store.allCookies() where site.owns(cookieDomain: cookie.domain) {
                current[TemporaryCookieFile.key(cookie)] = TemporaryCookieFile.Stamp(cookie)
            }
            for cookie in NetscapeCookies.parse(text) where site.owns(cookieDomain: cookie.domain) {
                let key = TemporaryCookieFile.key(cookie)
                guard let started = file.written[key], current[key] == started,
                      TemporaryCookieFile.Stamp(cookie) != started else { continue }
                await self.store.setCookie(cookie)
            }
        }
    }

    func signOut(_ site: SignInSite) async {
        await serialized {
            self.signOuts[site.id, default: 0] += 1
            for cookie in await self.store.allCookies() where site.owns(cookieDomain: cookie.domain) {
                await self.store.deleteCookie(cookie)
            }
        }
        await refresh()
    }

    /// Runs cookie operations one at a time, in order, so a sign-out can't land in
    /// the middle of a read or a write-back.
    @ObservationIgnored private var lastOperation: Task<Void, Never>?

    private func serialized(_ operation: @escaping @MainActor () async -> Void) async {
        let previous = lastOperation
        let task = Task { @MainActor in
            await previous?.value
            await operation()
        }
        lastOperation = task
        await task.value
    }

    func site(for url: URL) -> SignInSite? { SignInSite.site(for: url, in: sites) }

    // MARK: Custom sites

    /// Adds a site by address and returns it, or the existing site for that domain.
    func addSite(_ text: String) -> SignInSite? {
        guard let site = SignInSite.custom(from: text) else { return nil }
        // A subdomain of a listed site is that site: a separate row would share its
        // cookies, and removing it would sign out of the parent.
        if let existing = sites.first(where: { $0.owns(cookieDomain: site.cookieDomains[0]) }) {
            return existing
        }
        sites.append(site)
        saveCustomSites()
        return site
    }

    /// Signs out of a custom site and forgets it.
    func removeSite(_ site: SignInSite) async {
        guard site.isCustom else { return }
        await signOut(site)
        sites.removeAll { $0.id == site.id }
        saveCustomSites()
    }

    private static let customSitesKey = "customSignInSites"

    private static func loadCustomSites() -> [SignInSite] {
        guard let data = UserDefaults.standard.data(forKey: customSitesKey) else { return [] }
        return (try? JSONDecoder().decode([SignInSite].self, from: data)) ?? []
    }

    private func saveCustomSites() {
        let custom = sites.filter(\.isCustom)
        UserDefaults.standard.set(try? JSONEncoder().encode(custom), forKey: Self.customSitesKey)
    }

    nonisolated func cookiesDidChange(in _: WKHTTPCookieStore) {
        Task { @MainActor in self.scheduleRefresh() }
    }

    /// A sign-in sets many cookies at once; refresh once they settle.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        pendingRefresh = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await refresh()
        }
    }
}
