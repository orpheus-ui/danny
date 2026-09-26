import Foundation
import Observation

enum CapturedMediaKind: String, Codable {
    case hls
    case dash
    case video
    case audio
    case other

    var label: String {
        switch self {
        case .hls: "HLS"
        case .dash: "DASH"
        case .video: "VIDEO"
        case .audio: "AUDIO"
        case .other: "FILE"
        }
    }
}

struct CapturedMedia: Identifiable, Equatable {
    let id: UUID
    let url: URL
    let kind: CapturedMediaKind
    let capturedAt: Date

    init(url: URL, kind: CapturedMediaKind) {
        id = UUID()
        self.url = url
        self.kind = kind
        capturedAt = Date()
    }
}

@Observable
@MainActor
final class SnifferStore {
    private(set) var captured: [CapturedMedia] = []

    private static let ignoredExtensions = [
        "svg", "css", "js", "mjs", "woff", "woff2", "ttf", "otf", "eot",
        "png", "jpg", "jpeg", "gif", "webp", "avif", "ico",
        "json", "xml", "html", "htm", "txt", "vtt", "srt", "wasm", "webmanifest",
    ]

    func capture(rawURL: String) {
        guard let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme)
        else { return }
        let path = url.path.lowercased()
        if Self.ignoredExtensions.contains(where: { path.hasSuffix("." + $0) }) { return }
        guard !captured.contains(where: { $0.url == url }) else { return }
        let kind = Self.classify(url)
        captured.insert(CapturedMedia(url: url, kind: kind), at: 0)
        if captured.count > 300 {
            captured.removeLast(captured.count - 300)
        }
    }

    func clear() {
        captured.removeAll()
    }

    static func classify(_ url: URL) -> CapturedMediaKind {
        let query = url.query.map { "?\($0)".lowercased() } ?? ""
        let lowercased = url.path.lowercased() + query
        let host = url.host?.lowercased() ?? ""
        if lowercased.contains(".m3u8") || lowercased.contains("m3u8") { return .hls }
        if lowercased.contains(".mpd") { return .dash }
        if lowercased.contains("videoplayback") || host.contains("googlevideo") { return .video }
        let videoExtensions = [".mp4", ".webm", ".mov", ".m4v", ".mkv", ".flv", ".ts"]
        if videoExtensions.contains(where: { lowercased.contains($0) }) { return .video }
        let audioExtensions = [".m4a", ".mp3", ".aac", ".opus", ".ogg", ".wav", ".flac"]
        if audioExtensions.contains(where: { lowercased.contains($0) }) { return .audio }
        return .other
    }
}
