import AppKit
import CoreTransferable

/// Finds the video link in what the user pastes, copies or drops onto the window.
/// Nonisolated: drops are imported off the main actor.
nonisolated enum LinkIntake {
    /// The clipboard's link: a copied URL or `.webloc` file first, then the first link in its text.
    @MainActor static func pasteboardLink(_ pasteboard: NSPasteboard = .general) -> URL? {
        let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] ?? []
        return urls.lazy.compactMap(link(from:)).first
            ?? pasteboard.string(forType: .string).flatMap(link(from:))
    }

    /// The first http(s) link in the text.
    static func link(from text: String) -> URL? {
        let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector?.matches(in: text, range: NSRange(text.startIndex..., in: text)) ?? []
        return matches.lazy.compactMap { $0.url.flatMap(link(from:)) }.first
    }

    /// A web link as it is, the link inside a `.webloc` file, nil for anything else.
    static func link(from url: URL) -> URL? {
        if url.isFileURL {
            // A real .webloc is under 1 KB; the cap keeps a huge or remote file from stalling a paste.
            guard url.pathExtension.lowercased() == "webloc",
                  let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size <= 64 * 1024,
                  let data = try? Data(contentsOf: url),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
                  let string = (plist as? [String: Any])?["URL"] as? String,
                  let inner = URL(string: string), !inner.isFileURL
            else { return nil }
            return link(from: inner)
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else { return nil }
        return url
    }
}

/// Something dropped on the window that holds a link: a URL (a link dragged from
/// a browser, or a `.webloc` file from Finder) or text with a link in it.
nonisolated struct DroppedLink: Transferable {
    let url: URL

    struct NoLink: Error {}

    static var transferRepresentation: some TransferRepresentation {
        ProxyRepresentation(importing: { (url: URL) in
            guard let link = LinkIntake.link(from: url) else { throw NoLink() }
            return DroppedLink(url: link)
        })
        ProxyRepresentation(importing: { (text: String) in
            guard let link = LinkIntake.link(from: text) else { throw NoLink() }
            return DroppedLink(url: link)
        })
    }
}
