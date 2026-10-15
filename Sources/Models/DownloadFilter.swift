import Foundation

/// What the search bar asks of the list: free text, a status scope and a site. The
/// text doubles as an add field: when it is a link, the bar offers to download it.
struct DownloadFilter: Equatable {
    enum Scope: String, CaseIterable, Identifiable {
        case all, active, done, failed

        var id: String { rawValue }

        var label: String {
            switch self {
            case .all: "All"
            case .active: "Active"
            case .done: "Done"
            case .failed: "Failed"
            }
        }

        func contains(_ status: ItemStatus) -> Bool {
            switch self {
            case .all: true
            case .active: status.isActive
            case .done: status == .finished
            case .failed: status == .failed
            }
        }
    }

    var text = ""
    var scope = Scope.all
    /// A site from `sites(in:)`, without `www.`.
    var site: String?

    var isEmpty: Bool { trimmedText.isEmpty && scope == .all && site == nil }

    /// The text as a link to download, when it is one: an explicit http(s) URL with a
    /// host. A bare `youtube.com` stays a search, so typing a site name filters.
    var link: URL? {
        guard !trimmedText.contains(where: \.isWhitespace),
              let url = URL(string: trimmedText),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              url.host?.isEmpty == false
        else { return nil }
        return url
    }

    func matches(_ item: DownloadItem) -> Bool {
        guard scope.contains(item.status) else { return false }
        if let site, Self.site(of: item) != site { return false }
        let text = trimmedText
        guard !text.isEmpty else { return true }
        if let link {
            return DownloadManager.normalize(item.sourceURL) == DownloadManager.normalize(link)
        }
        return item.title.localizedCaseInsensitiveContains(text)
            || item.host.localizedCaseInsensitiveContains(text)
            || item.sourceURL.absoluteString.localizedCaseInsensitiveContains(text)
    }

    /// How many items fall in each scope, ignoring the current scope.
    func counts(in items: [DownloadItem]) -> [Scope: Int] {
        var unscoped = self
        unscoped.scope = .all
        let matching = items.filter(unscoped.matches)
        return Dictionary(uniqueKeysWithValues: Scope.allCases.map { scope in
            (scope, matching.count { scope.contains($0.status) })
        })
    }

    /// The most common sites in the list, most first, then by name.
    static func sites(in items: [DownloadItem], limit: Int = 4) -> [String] {
        let counts = Dictionary(grouping: items, by: site(of:)).mapValues(\.count)
        return counts
            .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
            .prefix(limit)
            .map(\.key)
    }

    static func site(of item: DownloadItem) -> String {
        let host = item.host.lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    private var trimmedText: String { text.trimmingCharacters(in: .whitespacesAndNewlines) }
}
