import CryptoKit
import Foundation
import WebKit

/// Major ad and tracker hosts, written for Danny (ADR-019). A host matches itself
/// and its subdomains. Browser Capture blocks them, and media from them never
/// reaches the captured list.
enum AdHosts {
    static let hosts: [String] = [
        // Ads and ad video (pre-rolls, VAST, ad HLS)
        "doubleclick.net", "googlesyndication.com", "googleadservices.com",
        "googletagservices.com", "imasdk.googleapis.com", "adservice.google.com",
        "2mdn.net", "amazon-adsystem.com", "adnxs.com", "adsrvr.org",
        "rubiconproject.com", "pubmatic.com", "openx.net", "criteo.com", "criteo.net",
        "casalemedia.com", "indexww.com", "taboola.com", "outbrain.com",
        "moatads.com", "adsafeprotected.com", "doubleverify.com", "serving-sys.com",
        "spotxchange.com", "spotx.tv", "springserve.com", "teads.tv", "yieldmo.com",
        "smartadserver.com", "adform.net", "media.net", "advertising.com",
        "innovid.com", "tremorhub.com", "fwmrm.net", "freewheel.tv",
        "sharethrough.com", "33across.com", "lijit.com", "contextweb.com",
        "popads.net", "popcash.net", "propellerads.com", "exoclick.com",
        "juicyads.com", "trafficjunky.net", "adsterra.com", "hilltopads.net",
        // Trackers
        "google-analytics.com", "googletagmanager.com", "analytics.google.com",
        "scorecardresearch.com", "quantserve.com", "hotjar.com", "mixpanel.com",
        "cdn.segment.com", "api.segment.io", "bat.bing.com", "clarity.ms",
        "chartbeat.com", "chartbeat.net", "bam.nr-data.net", "js-agent.newrelic.com",
        "omtrdc.net", "demdex.net", "2o7.net", "krxd.net", "bluekai.com",
        "crwdcntrl.net", "rlcdn.com", "imrworldwide.com", "permutive.com",
        "id5-sync.com", "ads-twitter.com", "analytics.twitter.com",
        "ads.linkedin.com", "analytics.tiktok.com", "ct.pinterest.com", "mc.yandex.ru",
    ]

    static func contains(_ url: URL) -> Bool {
        guard let host = url.host()?.lowercased() else { return false }
        return hosts.contains { host == $0 || host.hasSuffix("." + $0) }
    }
}

/// The ad and tracker hosts as a WebKit content rule list, compiled once per list
/// and kept by `WKContentRuleListStore`, so WebKit blocks in its network process.
enum ContentBlocker {
    static let rulesJSON: String = {
        let rules = AdHosts.hosts.map { host in
            let pattern = "^[^:]+://+([^:/]+\\.)?" + host.replacingOccurrences(of: ".", with: "\\.") + "[:/]"
            let rule: [String: Any] = [
                "trigger": ["url-filter": pattern, "load-type": ["third-party"]],
                "action": ["type": "block"],
            ]
            return rule
        }
        let data = try? JSONSerialization.data(withJSONObject: rules, options: .sortedKeys)
        return data.flatMap { String(bytes: $0, encoding: .utf8) } ?? "[]"
    }()

    /// Named by a digest of the rules, so a list changed in an app update compiles again.
    static let identifier = "ads-" + SHA256.hash(data: Data(rulesJSON.utf8))
        .prefix(8).map { String(format: "%02x", $0) }.joined()

    /// Nil when WebKit can't compile the rules; Browser Capture then loads pages unblocked.
    @MainActor
    static func ruleList(in store: WKContentRuleListStore = .default()) async -> WKContentRuleList? {
        if let cached = try? await store.contentRuleList(forIdentifier: identifier) { return cached }
        return try? await store.compileContentRuleList(forIdentifier: identifier, encodedContentRuleList: rulesJSON)
    }
}
