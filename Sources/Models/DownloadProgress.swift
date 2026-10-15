import Foundation

/// Turns yt-dlp's per-file progress into one fraction for the whole download.
///
/// yt-dlp reports bytes for the file it is fetching now, named by its format id.
/// Sites like YouTube send video and audio as separate files, so the plan — the
/// files the probe said will be fetched and their approximate sizes — reserves
/// room for the files still to come. Reported sizes replace the plan's as they
/// arrive. The fraction only moves forward and stays below 1 until the download
/// is marked finished.
struct DownloadProgress {
    /// The highest fraction shown while bytes are still arriving.
    static let ceiling = 0.99

    private(set) var fraction: Double?
    /// Approximate size of each planned file, by format id.
    private let planned: [String: Int64]
    private var downloaded: [String: Int64] = [:]
    private var reported: [String: Int64] = [:]

    init(planned: [String: Int64] = [:]) {
        self.planned = planned.filter { $0.value > 0 }
    }

    /// Every file's size: reported when known, else planned, never below what
    /// already arrived. Nil until any size is known.
    var totalBytes: Int64? {
        guard !reported.isEmpty || !planned.isEmpty else { return nil }
        let seen = Set(reported.keys).union(downloaded.keys)
        // ffmpeg can fetch a merged download in one go, reported as "616+140": that
        // file stands for its planned parts, which then aren't counted again.
        let merged = Set(seen.flatMap(parts(of:)))
        let files = seen.union(planned.keys.filter { !merged.contains($0) })
        let total = files.reduce(Int64(0)) { sum, file in
            sum + max(reported[file] ?? plannedSize(of: file) ?? 0, downloaded[file] ?? 0)
        }
        return total > 0 ? total : nil
    }

    /// The planned parts a merged id joins; empty for a single file.
    private func parts(of file: String) -> [String] {
        let parts = file.split(separator: "+").map(String.init)
        return parts.count > 1 && parts.allSatisfy { planned[$0] != nil } ? parts : []
    }

    private func plannedSize(of file: String) -> Int64? {
        if let size = planned[file] { return size }
        let parts = parts(of: file)
        return parts.isEmpty ? nil : parts.compactMap { planned[$0] }.reduce(0, +)
    }

    /// `file` is the format id yt-dlp is fetching; a line with no total keeps that
    /// file's last known size.
    mutating func update(file: String? = nil, downloaded bytes: Int64, total: Int64?) -> Double? {
        let file = file ?? ""
        downloaded[file] = bytes
        if let total, total > 0 { reported[file] = total }

        guard let expected = totalBytes else { return fraction }
        let arrived = downloaded.values.reduce(0, +)
        fraction = min(max(Double(arrived) / Double(expected), fraction ?? 0), Self.ceiling)
        return fraction
    }
}
