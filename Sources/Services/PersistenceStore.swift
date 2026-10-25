import Foundation

enum PersistenceStore {
    static func historyURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("Danny", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    /// Decodes with the date format `save` writes, else nothing would survive a quit.
    static func load(from url: URL = historyURL()) -> [DownloadItem] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        return decode(from: data) ?? []
    }

    static func save(_ items: [DownloadItem], to url: URL = historyURL()) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: url, options: .atomic)
    }

    static func decode(from data: Data) -> [DownloadItem]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([DownloadItem].self, from: data)
    }
}
