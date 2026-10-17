import CFNetwork
import Foundation

/// The proxy System Settings has on, as yt-dlp arguments. Read when a run starts, so
/// there is nothing to observe or poll (ADR-008). PAC / auto-config and the bypass list are not followed.
nonisolated enum SystemProxy {
    /// Preference order; each is the dictionary's key prefix and the scheme yt-dlp needs.
    private static let kinds: [(prefix: String, scheme: String)] = [
        ("HTTPS", "http"), ("HTTP", "http"), ("SOCKS", "socks5"),
    ]

    static func url(from settings: [String: Any]) -> String? {
        for (prefix, scheme) in kinds {
            guard (settings["\(prefix)Enable"] as? Int) == 1,
                  let host = settings["\(prefix)Proxy"] as? String, !host.isEmpty,
                  let port = settings["\(prefix)Port"] as? Int else { continue }
            return "\(scheme)://\(host.contains(":") ? "[\(host)]" : host):\(port)"
        }
        return nil
    }

    static func arguments(from settings: [String: Any]) -> [String] {
        url(from: settings).map { ["--proxy", $0] } ?? []
    }

    static func current() -> [String] {
        arguments(from: CFNetworkCopySystemProxySettings()?.takeRetainedValue() as? [String: Any] ?? [:])
    }
}
