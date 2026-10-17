import AppKit

/// A site's icon, fetched once and kept: the first link from a host downloads its
/// `/favicon.ico` into Application Support, and every later link from it (or from its
/// `www.` twin) reads that file. A site with no usable icon is asked again next launch.
@MainActor
final class Favicons {
    static let shared = Favicons()

    private let folder: URL
    private let fetch: (URL) async -> Data?
    private var memory: [String: NSImage] = [:]
    private var missing: Set<String> = []

    init(
        folder: URL = Favicons.defaultFolder,
        fetch: @escaping (URL) async -> Data? = Favicons.download,
    ) {
        self.folder = folder
        self.fetch = fetch
    }

    /// The cache key: the host without `www.`, lowercased.
    nonisolated static func key(for host: String) -> String {
        let host = host.lowercased()
        return host.hasPrefix("www.") ? String(host.dropFirst(4)) : host
    }

    func image(for host: String) async -> NSImage? {
        let key = Self.key(for: host)
        guard !key.isEmpty, !key.contains("/"), !missing.contains(key) else { return nil }
        if let image = memory[key] { return image }
        let file = folder.appendingPathComponent(key + ".ico")
        if let data = try? Data(contentsOf: file), let image = NSImage(data: data) {
            memory[key] = image
            return image
        }
        guard let url = URL(string: "https://\(key)/favicon.ico"), let data = await fetch(url),
              let image = NSImage(data: data)
        else {
            missing.insert(key)
            return nil
        }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? data.write(to: file)
        memory[key] = image
        return image
    }

    nonisolated static var defaultFolder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent("Danny/Favicons", isDirectory: true)
    }

    /// A small image from the site itself, nothing sent anywhere else.
    nonisolated static func download(_ url: URL) async -> Data? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        guard let (data, response) = try? await URLSession.shared.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200, data.count < 256 * 1024
        else { return nil }
        return data
    }
}
