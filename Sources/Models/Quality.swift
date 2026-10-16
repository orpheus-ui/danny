import Foundation

/// The quality setting: a ceiling, audio only, or ask for each download.
enum QualityPreference: String, CaseIterable, Identifiable, Codable {
    case best, upTo2160, upTo1440, upTo1080, upTo720, upTo480, audioOnly, ask

    var id: String { rawValue }

    var label: String {
        switch self {
        case .best: "Best available"
        case .upTo2160: "Up to 4K"
        case .upTo1440: "Up to 1440p"
        case .upTo1080: "Up to 1080p"
        case .upTo720: "Up to 720p"
        case .upTo480: "Up to 480p"
        case .audioOnly: "Audio only"
        case .ask: "Ask each time"
        }
    }

    /// The choice it makes without asking; nil for `.ask`.
    var choice: QualityChoice? {
        switch self {
        case .best: .video(maxHeight: nil)
        case .upTo2160: .video(maxHeight: 2160)
        case .upTo1440: .video(maxHeight: 1440)
        case .upTo1080: .video(maxHeight: 1080)
        case .upTo720: .video(maxHeight: 720)
        case .upTo480: .video(maxHeight: 480)
        case .audioOnly: .audio
        case .ask: nil
        }
    }
}

/// What files come out: ones every Apple app plays, or the best the site has.
enum FormatPreference: String, CaseIterable, Identifiable, Codable {
    /// H.264 or HEVC video and AAC audio in MP4: QuickTime, Photos, iPhone, editors.
    case compatible
    /// Any codec. YouTube's 4K and up are VP9 or AV1, which QuickTime may not play.
    case highest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .compatible: "Plays everywhere"
        case .highest: "Highest quality"
        }
    }
}

/// The quality of one download.
enum QualityChoice: Codable, Hashable, Sendable {
    case video(maxHeight: Int?)
    case audio
}

/// One option offered on the card when the setting is "Ask each time".
struct QualityOption: Codable, Hashable, Identifiable, Sendable {
    let choice: QualityChoice
    let label: String
    /// Estimated size of the download, when the site lists sizes.
    let bytes: Int64?

    var id: String { label }
}

/// One format the site offers, as the probe lists it.
nonisolated struct FormatInfo: Decodable, Sendable {
    var formatID: String
    var height: Int?
    var vcodec: String?
    var acodec: String?
    var filesize: Int64?
    var filesizeApprox: Int64?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case height, vcodec, acodec, filesize
        case filesizeApprox = "filesize_approx"
    }

    var size: Int64? { filesize ?? filesizeApprox }
    var hasVideo: Bool { vcodec.map { $0 != "none" } ?? false }
    var hasAudio: Bool { acodec.map { $0 != "none" } ?? false }
    /// H.264 or HEVC: plays in QuickTime and on every Apple device.
    var isCompatibleVideo: Bool {
        guard let vcodec = vcodec?.lowercased() else { return false }
        return ["avc1", "h264", "hvc1", "hev1", "h265"].contains { vcodec.hasPrefix($0) }
    }
}

/// yt-dlp arguments and card options for a quality choice.
nonisolated enum QualitySelection {
    private static let compatibleVideo = "[vcodec~='^(avc1|h264|hvc1|hev1|h265)']"

    static func arguments(for choice: QualityChoice, format: FormatPreference) -> [String] {
        switch choice {
        case let .video(maxHeight):
            let height = maxHeight.map { "[height<=\($0)]" } ?? ""
            var choices: [String] = []
            if format == .compatible {
                // Compatible codecs first: a video-only stream with AAC, or one file
                // that already has both. `bv*` could bring its own non-AAC audio.
                choices += [
                    "bv\(compatibleVideo)\(height)+ba[acodec^=mp4a]",
                    "b\(compatibleVideo)\(height)[acodec^=mp4a]",
                ]
            }
            // Then any codec under the cap, then anything rather than failing.
            choices += ["bv*\(height)+ba", "b\(height)", "bv*+ba", "b"]
            var seen = Set<String>()
            let selector = choices.filter { seen.insert($0).inserted }.joined(separator: "/")
            // MP4 when the codecs allow it, else MKV.
            var arguments = ["-f", selector, "--merge-output-format", "mp4/mkv"]
            if let maxHeight {
                // When nothing is under the cap, the uncapped fallback takes the
                // smallest height above it, not the largest.
                arguments += ["-S", "res:\(maxHeight)"]
            }
            if format == .compatible {
                // A single file needs no merge, so it is remuxed to MP4 instead;
                // WebM and MKV keep their container, since MP4 can't promise to
                // play their codecs.
                arguments += ["--remux-video", "webm>webm/mkv>mkv/mp4"]
            }
            return arguments
        case .audio:
            switch format {
            case .compatible: return ["-f", "ba[acodec^=mp4a]/ba", "-x", "--audio-format", "m4a"]
            case .highest: return ["-f", "ba", "-x"]
            }
        }
    }

    /// The common heights. Each is offered when the site has a video at or under
    /// it and above the next one down.
    private static let steps: [(height: Int, label: String)] = [
        (2160, "4K"), (1440, "1440p"), (1080, "1080p"), (720, "720p"), (480, "480p"), (360, "360p"),
    ]

    /// Options for the card, best first, ending with audio when the site has it.
    /// With `.compatible`, heights come from compatible videos only (when the site
    /// has any), so a "4K" chip never stands for a 1080p download.
    static func options(from formats: [FormatInfo], format: FormatPreference) -> [QualityOption] {
        let allVideos = formats.filter(\.hasVideo)
        let compatible = allVideos.filter(\.isCompatibleVideo)
        let videos = format == .compatible && !compatible.isEmpty ? compatible : allVideos
        let audio = formats.filter { $0.hasAudio && !$0.hasVideo }
        let bestAudio = audio.max { ($0.size ?? 0) < ($1.size ?? 0) }

        var options: [QualityOption] = []
        for (index, step) in steps.enumerated() {
            let floor = index + 1 < steps.count ? steps[index + 1].height : 0
            let best = videos
                .filter { ($0.height ?? 0) <= step.height && ($0.height ?? 0) > floor }
                .max { ($0.height ?? 0, $0.size ?? 0) < ($1.height ?? 0, $1.size ?? 0) }
            guard let best else { continue }
            let bytes = best.size.map { $0 + (best.hasAudio ? 0 : bestAudio?.size ?? 0) }
            options.append(QualityOption(choice: .video(maxHeight: step.height), label: step.label, bytes: bytes))
        }
        if let bestAudio {
            options.append(QualityOption(choice: .audio, label: "Audio", bytes: bestAudio.size))
        }
        return options
    }
}
