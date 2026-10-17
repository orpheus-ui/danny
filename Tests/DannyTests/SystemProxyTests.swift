@testable import Danny
import Foundation
import Testing

struct SystemProxyTests {
    private let https: [String: Any] = ["HTTPSEnable": 1, "HTTPSProxy": "secure.example", "HTTPSPort": 8443]
    private let http: [String: Any] = ["HTTPEnable": 1, "HTTPProxy": "plain.example", "HTTPPort": 8080]
    private let socks: [String: Any] = ["SOCKSEnable": 1, "SOCKSProxy": "socks.example", "SOCKSPort": 1080]

    @Test func `uses the HTTPS proxy`() {
        #expect(SystemProxy.url(from: https) == "http://secure.example:8443")
    }

    @Test func `uses the HTTP proxy`() {
        #expect(SystemProxy.url(from: http) == "http://plain.example:8080")
    }

    @Test func `uses the SOCKS proxy`() {
        #expect(SystemProxy.url(from: socks) == "socks5://socks.example:1080")
    }

    @Test func `brackets an IPv6 proxy address`() {
        #expect(SystemProxy.url(from: ["HTTPEnable": 1, "HTTPProxy": "::1", "HTTPPort": 8080]) == "http://[::1]:8080")
    }

    @Test func `prefers HTTPS, then HTTP, then SOCKS`() {
        #expect(SystemProxy.url(from: https.merging(http) { $1 }.merging(socks) { $1 }) == "http://secure.example:8443")
        #expect(SystemProxy.url(from: http.merging(socks) { $1 }) == "http://plain.example:8080")
    }

    @Test func `no proxy settings give no URL`() {
        #expect(SystemProxy.url(from: [:]) == nil)
        #expect(SystemProxy.url(from: ["ExceptionsList": ["*.local"], "FTPPassive": 1]) == nil)
    }

    @Test func `a disabled proxy is ignored`() {
        #expect(SystemProxy.url(from: ["HTTPSEnable": 0, "HTTPSProxy": "secure.example", "HTTPSPort": 8443]) == nil)
        let offHTTPS: [String: Any] = ["HTTPSEnable": 0, "HTTPSProxy": "secure.example", "HTTPSPort": 8443]
        #expect(SystemProxy.url(from: offHTTPS.merging(http) { $1 }) == "http://plain.example:8080")
    }

    @Test func `an enabled proxy without a host or port is ignored`() {
        #expect(SystemProxy.url(from: ["HTTPSEnable": 1, "HTTPSProxy": "secure.example"]) == nil)
        #expect(SystemProxy.url(from: ["HTTPSEnable": 1, "HTTPSPort": 8443]) == nil)
        #expect(SystemProxy.url(from: ["HTTPSEnable": 1, "HTTPSProxy": "", "HTTPSPort": 8443]) == nil)
    }

    @Test func `adds --proxy only when a proxy is set`() {
        #expect(SystemProxy.arguments(from: https) == ["--proxy", "http://secure.example:8443"])
        #expect(SystemProxy.arguments(from: [:]).isEmpty)
        #expect(SystemProxy.arguments(from: ["HTTPEnable": 0]).isEmpty)
    }
}
