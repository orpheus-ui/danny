import Foundation

/// Turns yt-dlp's per-file progress into one fraction for the whole download.
///
/// yt-dlp reports bytes for the file it is fetching now. Sites like YouTube send
/// video and audio as two files, so the count restarts for the second; and a file
/// can run past its reported size. The fraction here spans every file, only moves
/// forward, and stays below 1 until the download is marked finished.
struct DownloadProgress {
    /// The highest fraction shown while bytes are still arriving.
    static let ceiling = 0.99

    private(set) var fraction: Double?
    /// Bytes of the files already finished.
    private var finishedBytes: Int64 = 0
    private var currentDownloaded: Int64 = 0
    private var currentTotal: Int64?

    /// Every finished file plus the current one's expected size, when known.
    var totalBytes: Int64? {
        currentTotal.map { finishedBytes + max($0, currentDownloaded) }
    }

    /// A line with no total keeps the current file's last known size.
    mutating func update(downloaded: Int64, total: Int64?) -> Double? {
        if downloaded < currentDownloaded {
            // The count went back: a new file started.
            finishedBytes += max(currentTotal ?? 0, currentDownloaded)
            currentTotal = nil
        }
        currentDownloaded = downloaded
        if let total, total > 0 { currentTotal = total }

        guard let expected = totalBytes, expected > 0 else { return fraction }
        let raw = Double(finishedBytes + downloaded) / Double(expected)
        fraction = min(max(raw, fraction ?? 0), Self.ceiling)
        return fraction
    }
}
