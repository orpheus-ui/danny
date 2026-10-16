import Foundation

/// A site Danny can sign in to, so yt-dlp downloads as the signed-in user. The
/// sign-in happens in Danny's own browser; only the cookies for `cookieDomains`
/// are handed to yt-dlp. Sites are data: a new built-in site is one more entry in
/// `builtIn`, and users add any other site with `custom(from:)`.
struct SignInSite: Identifiable, Hashable, Sendable, Codable {
    let id: String
    let name: String
    let loginURL: URL
    /// Domains whose cookies yt-dlp gets, without a leading dot.
    let cookieDomains: [String]
    /// Short-link hosts that belong to the site (`youtu.be`).
    var aliasHosts: [String] = []
    /// Any of these cookies on `cookieDomains` means a signed-in session. Empty for a
    /// custom site, where any lasting cookie on its domain counts.
    var sessionCookies: Set<String> = []

    var isCustom: Bool { id.hasPrefix(Self.customPrefix) }

    /// Downloads go signed out first and use the session only when the site asks.
    /// YouTube serves some signed-in accounts only SABR streams, which yt-dlp can't
    /// read, so signed in they'd get 360p where signed out gets every quality.
    var signsInOnlyWhenAsked: Bool { id == Self.youtube.id }

    static let builtIn: [SignInSite] = [youtube, instagram, x, facebook]

    static let youtube = SignInSite(
        id: "youtube", name: "YouTube",
        loginURL: URL(
            string: "https://accounts.google.com/ServiceLogin?service=youtube&continue=https%3A%2F%2Fwww.youtube.com%2F",
        )!,
        cookieDomains: ["youtube.com", "google.com"],
        aliasHosts: ["youtu.be"],
        sessionCookies: ["LOGIN_INFO", "SAPISID", "__Secure-3PSID"],
    )
    static let instagram = SignInSite(
        id: "instagram", name: "Instagram",
        loginURL: URL(string: "https://www.instagram.com/accounts/login/")!,
        cookieDomains: ["instagram.com"],
        sessionCookies: ["sessionid"],
    )
    static let x = SignInSite(
        id: "x", name: "X",
        loginURL: URL(string: "https://x.com/i/flow/login")!,
        cookieDomains: ["x.com", "twitter.com"],
        aliasHosts: ["t.co"],
        sessionCookies: ["auth_token"],
    )
    static let facebook = SignInSite(
        id: "facebook", name: "Facebook",
        loginURL: URL(string: "https://www.facebook.com/login/")!,
        cookieDomains: ["facebook.com"],
        aliasHosts: ["fb.watch"],
        sessionCookies: ["c_user"],
    )

    private static let customPrefix = "custom:"

    /// A site the user adds by address: `vimeo.com` or `https://vimeo.com/log_in`.
    static func custom(from text: String) -> SignInSite? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme), let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http",
              let host = url.host?.lowercased(), host.contains(".")
        else { return nil }
        let domain = host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
        return SignInSite(id: customPrefix + domain, name: domain, loginURL: url, cookieDomains: [domain])
    }

    /// The site a download link belongs to, for its cookies and for offering sign-in.
    static func site(for url: URL, in sites: [SignInSite] = builtIn) -> SignInSite? {
        guard let host = url.host?.lowercased() else { return nil }
        return sites.first { site in
            site.aliasHosts.contains(host) || site.cookieDomains.contains { host == $0 || host.hasSuffix("." + $0) }
        }
    }

    func owns(cookieDomain domain: String) -> Bool {
        let bare = domain.hasPrefix(".") ? String(domain.dropFirst()) : domain
        return cookieDomains.contains { bare == $0 || bare.hasSuffix("." + $0) }
    }

    func isSignedIn(with cookies: [HTTPCookie]) -> Bool {
        cookies.contains { cookie in
            guard owns(cookieDomain: cookie.domain) else { return false }
            return sessionCookies.isEmpty ? !cookie.isSessionOnly : sessionCookies.contains(cookie.name)
        }
    }
}

extension DownloadItem {
    /// Whether this item failed because the site wants a signed-in user (YouTube's
    /// bot check, private or age-restricted videos).
    var asksForSignIn: Bool {
        status == .failed && errorMessage.map(Self.asksForSignIn) == true
    }

    static func asksForSignIn(_ message: String) -> Bool {
        let lowered = message.lowercased().replacingOccurrences(of: "’", with: "'")
        return ["sign in", "log in", "login required", "--cookies", "not a bot"].contains { lowered.contains($0) }
    }
}

/// Cookies in the Netscape `cookies.txt` format that yt-dlp's `--cookies` reads.
nonisolated enum NetscapeCookies {
    static func format(_ cookies: [HTTPCookie]) -> String {
        var lines = ["# Netscape HTTP Cookie File"]
        for cookie in cookies {
            let domain = cookie.isHTTPOnly ? "#HttpOnly_" + cookie.domain : cookie.domain
            let fields = [
                domain,
                cookie.domain.hasPrefix(".") ? "TRUE" : "FALSE",
                cookie.path,
                cookie.isSecure ? "TRUE" : "FALSE",
                String(Int(cookie.expiresDate?.timeIntervalSince1970 ?? 0)),
                cookie.name,
                cookie.value,
            ]
            lines.append(fields.joined(separator: "\t"))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    /// Reads a file in the same format, as yt-dlp writes it back after a run.
    static func parse(_ text: String) -> [HTTPCookie] {
        text.split(whereSeparator: \.isNewline).compactMap { line in
            var line = String(line)
            let httpOnly = line.hasPrefix("#HttpOnly_")
            if httpOnly { line.removeFirst("#HttpOnly_".count) }
            guard !line.hasPrefix("#") else { return nil }
            let fields = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            guard fields.count == 7 else { return nil }
            var properties: [HTTPCookiePropertyKey: Any] = [
                .domain: fields[0], .path: fields[2], .name: fields[5], .value: fields[6],
            ]
            if fields[3] == "TRUE" { properties[.secure] = "TRUE" }
            if let seconds = TimeInterval(fields[4]), seconds > 0 {
                properties[.expires] = Date(timeIntervalSince1970: seconds)
            }
            if httpOnly { properties[HTTPCookiePropertyKey("HttpOnly")] = "TRUE" }
            return HTTPCookie(properties: properties)
        }
    }
}
