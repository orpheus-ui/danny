@testable import Danny
import Testing

struct CardStateTests {
    @Test
    func `queued says so, or that it waits for Wi-Fi`() {
        let item = DownloadItem.sample(.queued)
        #expect(ProgressBarView.labelParts(for: item, waitsForWiFi: false) == ["Queued"])
        #expect(ProgressBarView.labelParts(for: item, waitsForWiFi: true) == ["Waiting for Wi-Fi"])
    }

    @Test(arguments: [
        (ItemStatus.resolving, ["Fetching…"]),
        (.processing, ["Merging…"]),
        (.paused, ["Paused", "·", "59%"]),
        (.finished, ["Done"]),
    ])
    func `each state labels its bar`(status: ItemStatus, label: [String]) {
        #expect(ProgressBarView.labelParts(for: .sample(status), waitsForWiFi: false) == label)
    }

    @Test
    func `fetching and paused dim the fill, others draw it fully`() {
        #expect(ProgressBarView.fillOpacity(for: .resolving) == D.dimmedFill)
        #expect(ProgressBarView.fillOpacity(for: .paused) == D.dimmedFill)
        for status in [ItemStatus.downloading, .processing, .finished, .failed] {
            #expect(ProgressBarView.fillOpacity(for: status) == 1)
        }
    }

    @Test(arguments: [
        ItemStatus.queued, .resolving, .choosing, .existing, .downloading, .processing, .paused, .finished, .failed,
    ])
    func `every state has a sample card`(status: ItemStatus) {
        #expect(DownloadItem.samples.contains { $0.status == status })
    }
}
