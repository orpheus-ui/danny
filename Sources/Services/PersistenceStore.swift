import Foundation

enum PersistenceStore {
    static func historyURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        let dir = base.appendingPathComponent("Danny", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("history.json")
    }

    static func load() -> [DownloadItem] {
        let url = historyURL()
        guard let data = try? Data(contentsOf: url),
              let items = try? JSONDecoder().decode([DownloadItem].self, from: data)
        else { return [] }
        return items
    }

    static func save(_ items: [DownloadItem]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(items) else { return }
        try? data.write(to: historyURL(), options: .atomic)
    }

    static func decode(from data: Data) -> [DownloadItem]? {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([DownloadItem].self, from: data)
    }
}
