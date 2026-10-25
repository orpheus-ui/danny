@testable import Danny
import Testing
import WebKit

struct WebCacheTests {
    @Test func `clears caches only`() {
        #expect(!WebCache.dataTypes.isEmpty)
        #expect(WebCache.dataTypes.allSatisfy { $0.contains("Cache") })
    }

    @Test func `keeps everything that holds A sign in`() {
        let signInData: Set<String> = [
            WKWebsiteDataTypeCookies, WKWebsiteDataTypeLocalStorage, WKWebsiteDataTypeSessionStorage,
            WKWebsiteDataTypeIndexedDBDatabases, WKWebsiteDataTypeWebSQLDatabases,
            WKWebsiteDataTypeServiceWorkerRegistrations, WKWebsiteDataTypeFileSystem,
        ]
        #expect(WebCache.dataTypes.isDisjoint(with: signInData))
    }
}
