@testable import Danny
import Foundation
import Testing

struct QualityTests {
    private func video(_ id: String, _ height: Int, _ vcodec: String, size: Int64) -> FormatInfo {
        FormatInfo(formatID: id, height: height, vcodec: vcodec, acodec: "none", filesize: size)
    }

    private let audio = FormatInfo(formatID: "140", height: nil, vcodec: "none", acodec: "mp4a.40.2", filesize: 10)

    /// A typical YouTube list: 4K and 1440p only in VP9, H.264 up to 1080p.
    private var youtube: [FormatInfo] {
        [
            video("313", 2160, "vp9", size: 4000), video("271", 1440, "vp9", size: 2000),
            video("137", 1080, "avc1.640028", size: 900), video("248", 1080, "vp9", size: 800),
            video("136", 720, "avc1.4d401f", size: 400), audio,
        ]
    }

    @Test
    func `plays everywhere offers only heights that come in compatible codecs`() {
        let options = QualitySelection.options(from: youtube, format: .compatible)
        #expect(options.map(\.label) == ["1080p", "720p", "Audio"])
        #expect(options.first?.bytes == 910)
    }

    @Test
    func `highest quality offers every height`() {
        let options = QualitySelection.options(from: youtube, format: .highest)
        #expect(options.map(\.label) == ["4K", "1440p", "1080p", "720p", "Audio"])
        #expect(options.first?.bytes == 4010)
    }

    @Test
    func `a site with no compatible video still gets options`() {
        let formats = [video("1", 1080, "vp9", size: 100), audio]
        #expect(QualitySelection.options(from: formats, format: .compatible).map(\.label) == ["1080p", "Audio"])
    }

    @Test
    func `video arguments cap the height and prefer compatible codecs`() {
        let arguments = QualitySelection.arguments(for: .video(maxHeight: 1080), format: .compatible)
        let selector = arguments[1]
        #expect(arguments[0] == "-f")
        #expect(selector.hasPrefix("bv[vcodec~='^(avc1|h264|hvc1|hev1|h265)'][height<=1080]+ba[acodec^=mp4a]/"
                + "b[vcodec~='^(avc1|h264|hvc1|hev1|h265)'][height<=1080][acodec^=mp4a]/"))
        #expect(selector.hasSuffix("/bv*+ba/b"))
        #expect(arguments.dropFirst(2).prefix(2) == ["--merge-output-format", "mp4/mkv"])
        #expect(arguments.contains("--remux-video"))
    }

    /// With nothing under the cap, the closest height above it wins, not the largest.
    @Test
    func `a height cap sorts the fallback by closeness to the cap`() {
        let arguments = QualitySelection.arguments(for: .video(maxHeight: 480), format: .highest)
        #expect(arguments.suffix(2) == ["-S", "res:480"])
    }

    @Test
    func `best has no height cap and no repeated fallback`() {
        let arguments = QualitySelection.arguments(for: .video(maxHeight: nil), format: .highest)
        #expect(arguments == ["-f", "bv*+ba/b", "--merge-output-format", "mp4/mkv"])
    }

    @Test
    func `audio is extracted, as AAC when it has to play everywhere`() {
        #expect(QualitySelection.arguments(for: .audio, format: .compatible)
            == ["-f", "ba[acodec^=mp4a]/ba", "-x", "--audio-format", "m4a"])
        #expect(QualitySelection.arguments(for: .audio, format: .highest) == ["-f", "ba", "-x"])
    }

    @Test
    func `every preference but ask makes a choice`() {
        #expect(QualityPreference.allCases.filter { $0.choice == nil } == [.ask])
        #expect(QualityPreference.upTo720.choice == .video(maxHeight: 720))
    }
}
