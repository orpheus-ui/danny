import AVFoundation
import Foundation

/// Files from earlier downloads of the same video. Downloads are named
/// `<title> [<id>].<ext>`, so a file carrying the id is the same video even after
/// a title change or with another container.
nonisolated enum ExistingFiles {
    static let videoExtensions: Set = ["mp4", "mkv", "webm", "mov", "m4v"]
    static let audioExtensions: Set = ["m4a", "mp3", "opus", "ogg", "aac", "flac", "wav"]

    /// A finished file of the same kind (video or audio) for this id, if any.
    static func find(id: String, audio: Bool, in directory: URL) -> URL? {
        let kinds = audio ? audioExtensions : videoExtensions
        return files(for: id, in: directory)
            .filter { kinds.contains($0.pathExtension.lowercased()) }
            .min { $0.lastPathComponent.count < $1.lastPathComponent.count }
    }

    /// The suffix for "Keep Both": " (2)", or the first number no file uses yet.
    static func keepBothSuffix(id: String, in directory: URL) -> String {
        let names = files(for: id, in: directory).map(\.lastPathComponent)
        var number = 2
        while names.contains(where: { $0.contains("[\(id)] (\(number)).") }) {
            number += 1
        }
        return " (\(number))"
    }

    /// The video's size as "1920x1080", like the probe's label; nil for audio or
    /// a file AVFoundation can't read (WebM).
    static func resolution(of file: URL) async -> String? {
        guard let track = try? await AVURLAsset(url: file).loadTracks(withMediaType: .video).first,
              let size = try? await track.load(.naturalSize), size.width > 0, size.height > 0
        else { return nil }
        return "\(Int(size.width))x\(Int(size.height))"
    }

    /// An unfinished download's files: more than one extension after the id, as in
    /// `… [id].mp4.part`, `… [id].f137.mp4` or `… [id].mp4.ytdl`.
    static func partials(id: String, in directory: URL) -> [URL] {
        matching(marker(id) + #"(?: \(\d+\))?\.[^.]+\.[^/]+$"#, in: directory)
    }

    private static func files(for id: String, in directory: URL) -> [URL] {
        // The id ends the name, before any Keep Both number: a title that merely
        // contains "[id]" doesn't match, nor do merge parts (`… [id].f137.mp4`).
        matching(marker(id) + #"(?: \(\d+\))?\.[^.]+$"#, in: directory)
    }

    private static func marker(_ id: String) -> String {
        NSRegularExpression.escapedPattern(for: "[\(id)]")
    }

    private static func matching(_ pattern: String, in directory: URL) -> [URL] {
        let contents = (try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil))
            ?? []
        return contents.filter { $0.lastPathComponent.range(of: pattern, options: .regularExpression) != nil }
    }
}
