@testable import Danny
import Testing

struct DownloadProgressTests {
    @Test
    func `one file goes from zero toward one`() {
        var progress = DownloadProgress()
        #expect(progress.update(downloaded: 0, total: 100) == 0)
        #expect(progress.update(downloaded: 50, total: 100) == 0.5)
    }

    /// YouTube sends video and audio as two files; progress restarts for the second.
    @Test
    func `video then audio never passes one or goes back`() {
        var progress = DownloadProgress()
        var seen: [Double] = []
        for (downloaded, total) in [(0, 900), (450, 900), (900, 900), (0, 100), (50, 100), (100, 100)] {
            if let fraction = progress.update(downloaded: Int64(downloaded), total: Int64(total)) {
                seen.append(fraction)
            }
        }
        #expect(seen.allSatisfy { $0 <= 1 })
        #expect(seen == seen.sorted())
        #expect(progress.totalBytes == 1000)
    }

    @Test
    func `downloaded bytes beyond the reported total stay under one`() {
        var progress = DownloadProgress()
        let fraction = progress.update(downloaded: 49_000_000, total: 37_000_000)
        #expect(fraction.map { $0 <= 1 } == true)
    }

    @Test
    func `an unknown total keeps the last known size`() {
        var progress = DownloadProgress()
        #expect(progress.update(downloaded: 10, total: nil) == nil)
        _ = progress.update(downloaded: 40, total: 100)
        #expect(progress.update(downloaded: 60, total: nil) == 0.6)
    }
}
