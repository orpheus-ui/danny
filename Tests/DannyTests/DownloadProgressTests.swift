@testable import Danny
import Testing

struct DownloadProgressTests {
    @Test
    func `one file goes from zero toward one`() {
        var progress = DownloadProgress()
        #expect(progress.update(downloaded: 0, total: 100) == 0)
        #expect(progress.update(downloaded: 50, total: 100) == 0.5)
    }

    /// YouTube sends video and audio as two files. The plan reserves the audio's
    /// share, so the bar keeps moving through it instead of waiting at 99%.
    @Test
    func `video then audio moves through both files`() {
        var progress = DownloadProgress(planned: ["616": 900, "140": 100])
        let video: [Int64] = [0, 450, 900]
        let audio: [Int64] = [0, 50, 100]
        let seen = video.compactMap { progress.update(file: "616", downloaded: $0, total: 900) }
            + audio.compactMap { progress.update(file: "140", downloaded: $0, total: 100) }
        #expect(seen == [0, 0.45, 0.9, 0.9, 0.95, 0.99])
        #expect(progress.totalBytes == 1000)
    }

    /// The file id marks the change of file, even when the next file's first report
    /// is already larger than where the last one ended.
    @Test
    func `a new file is told apart by its id, not by a smaller count`() {
        var progress = DownloadProgress()
        _ = progress.update(file: "a", downloaded: 100, total: 100)
        _ = progress.update(file: "b", downloaded: 200, total: 200)
        #expect(progress.totalBytes == 300)
    }

    @Test
    func `reported sizes replace the plan's`() {
        var progress = DownloadProgress(planned: ["616": 37_000_000, "140": 3_000_000])
        let fraction = progress.update(file: "616", downloaded: 49_000_000, total: 353_000_000)
        #expect(progress.totalBytes == 356_000_000)
        #expect(fraction.map { $0 < 0.2 } == true)
    }

    @Test
    func `downloaded bytes beyond the reported total stay under one`() {
        var progress = DownloadProgress()
        let fraction = progress.update(downloaded: 49_000_000, total: 37_000_000)
        #expect(fraction.map { $0 <= DownloadProgress.ceiling } == true)
    }

    @Test
    func `an unknown total keeps the last known size`() {
        var progress = DownloadProgress()
        #expect(progress.update(downloaded: 10, total: nil) == nil)
        _ = progress.update(downloaded: 40, total: 100)
        #expect(progress.update(downloaded: 60, total: nil) == 0.6)
    }

    @Test
    func `progress never goes back`() {
        var progress = DownloadProgress(planned: ["a": 100])
        _ = progress.update(file: "a", downloaded: 80, total: 100)
        // A bigger reported size would lower the fraction; it holds instead.
        #expect(progress.update(file: "a", downloaded: 81, total: 1000) == 0.8)
    }
}
