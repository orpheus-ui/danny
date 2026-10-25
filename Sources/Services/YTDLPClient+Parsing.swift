import Foundation

// MARK: - Reading yt-dlp's output lines

nonisolated extension YTDLPClient {
    static func parseEvent(_ line: some StringProtocol) -> DownloadEvent? {
        alreadyDownloadedPath(line).map(DownloadEvent.alreadyDownloaded) ?? parseProgressLine(line)
    }

    /// The path in yt-dlp's `[download] <path> has already been downloaded` line.
    static func alreadyDownloadedPath(_ line: some StringProtocol) -> String? {
        let prefix = "[download] ", suffix = " has already been downloaded"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix) else { return nil }
        let path = line.dropFirst(prefix.count).dropLast(suffix.count)
        return path.isEmpty ? nil : String(path)
    }

    static func parseProgressLine(_ line: some StringProtocol) -> DownloadEvent? {
        guard line.hasPrefix("@P|") else { return nil }
        let fields = line.dropFirst(3).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3 || fields.count == 4 else { return nil }
        let downloaded = Int64(fields[0]) ?? 0
        let total = Int64(fields[1]).flatMap { $0 > 0 ? $0 : nil }
        let speed = parseSpeed(String(fields[2]))
        let file = fields.count == 4 && !fields[3].isEmpty && fields[3] != "NA" ? String(fields[3]) : nil
        return .progress(downloaded: downloaded, total: total, speedBytesPerSecond: speed, file: file)
    }

    static func parseSpeed(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let value = leadingNumber(trimmed), value >= 0 else { return nil }
        let lower = trimmed.lowercased()
        if lower.contains("gib") { return value * 1_073_741_824 }
        if lower.contains("mib") { return value * 1_048_576 }
        if lower.contains("kib") { return value * 1024 }
        if lower.contains("gb") { return value * 1_000_000_000 }
        if lower.contains("mb") { return value * 1_000_000 }
        if lower.contains("kb") { return value * 1000 }
        return value
    }

    private static func leadingNumber(_ text: String) -> Double? {
        var end = text.startIndex
        while end < text.endIndex,
              let scalar = text[end].unicodeScalars.first,
              scalar == "." || CharacterSet.decimalDigits.contains(scalar)
        {
            end = text.index(after: end)
        }
        guard end > text.startIndex else { return nil }
        return Double(text[text.startIndex ..< end].replacingOccurrences(of: ",", with: "."))
    }
}
