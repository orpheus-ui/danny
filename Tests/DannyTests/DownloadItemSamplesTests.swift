@testable import Danny
import Foundation
import Testing

struct DownloadItemSamplesTests {
    @Test
    func `samples show every state`() {
        let states = Set(DownloadItem.samples.map(\.status))
        #expect(states == [
            .queued,
            .resolving,
            .choosing,
            .existing,
            .downloading,
            .processing,
            .paused,
            .finished,
            .failed,
        ])
    }

    @Test
    func `sample thumbnail exists`() throws {
        let url = try #require(DownloadItem.samples.first?.thumbnailURL)
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
