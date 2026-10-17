import Foundation

/// How a downloaded file is named. Each preset is a yt-dlp output template that ends
/// in `[<id>]`: `ExistingFiles` recognizes a video by that, whatever precedes it.
nonisolated enum FilenameTemplate: String, CaseIterable, Identifiable {
    case title
    case titleAndSite
    case dateAndTitle

    var id: String { rawValue }

    var label: String {
        switch self {
        case .title: "Title"
        case .titleAndSite: "Title and Site"
        case .dateAndTitle: "Date and Title"
        }
    }

    /// The yt-dlp template for the name, without the extension. The title is cut by
    /// bytes so the whole name stays under the file system's limit.
    var ytdlp: String {
        switch self {
        case .title: "%(title).120B [%(id)s]"
        case .titleAndSite: "%(title).100B - %(webpage_url_domain)s [%(id)s]"
        case .dateAndTitle: "%(upload_date>%Y-%m-%d|undated)s - %(title).100B [%(id)s]"
        }
    }

    /// The path a made-up video would get, relative to the download folder.
    func preview(siteFolder: Bool) -> String {
        let name = switch self {
        case .title: "Big Buck Bunny [aqz-KE-bpKQ].mp4"
        case .titleAndSite: "Big Buck Bunny - youtube.com [aqz-KE-bpKQ].mp4"
        case .dateAndTitle: "2008-04-10 - Big Buck Bunny [aqz-KE-bpKQ].mp4"
        }
        return siteFolder ? "youtube.com/" + name : name
    }
}

/// The folder a link's downloads go to.
nonisolated enum SiteFolder {
    /// The site's name as people know it: the host without a `www.` or `m.` front.
    static func name(for url: URL) -> String? {
        guard var host = url.host(percentEncoded: false)?.lowercased(), !host.isEmpty else { return nil }
        for front in ["www.", "m."] where host.hasPrefix(front) && host.dropFirst(front.count).contains(".") {
            host.removeFirst(front.count)
        }
        return host
    }

    /// `root`, or the link's site folder inside it.
    static func directory(for url: URL, in root: URL, perSite: Bool) -> URL {
        guard perSite, let name = name(for: url) else { return root }
        return root.appendingPathComponent(name, isDirectory: true)
    }
}
