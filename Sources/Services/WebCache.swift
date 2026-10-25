import WebKit

/// Danny's browser cache (Browser Capture and sign-in pages), which nothing else bounds.
nonisolated enum WebCache {
    /// Cache types only. Cookies, local and session storage, IndexedDB and the like hold
    /// sign-ins, so they never go in here.
    static let dataTypes: Set<String> = [
        WKWebsiteDataTypeDiskCache,
        WKWebsiteDataTypeMemoryCache,
        WKWebsiteDataTypeFetchCache,
    ]

    @MainActor
    static func clear() async {
        await WKWebsiteDataStore.default().removeData(ofTypes: dataTypes, modifiedSince: .distantPast)
    }
}
