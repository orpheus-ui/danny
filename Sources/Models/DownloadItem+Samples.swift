#if DEBUG
    import Foundation

    extension DownloadItem {
        /// One item per state, matching the Figma cards. `-sample-queue` shows them.
        static var samples: [DownloadItem] {
            let thumbnail = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Images/sample-thumbnail.png")
            let states: [(ItemStatus, Double?)] = [
                (.downloading, 0.54), (.resolving, nil), (.processing, nil),
                (.finished, 1), (.failed, nil), (.queued, nil),
            ].reversed() // the list shows the newest first
            return states.enumerated().map { index, state in
                var item = DownloadItem(url: URL(string: "https://www.youtube.com/watch?v=sample\(index)")!)
                item.title = "Example Thumbnail video long text test how many characters fit"
                item.host = "youtube.com"
                item.resolution = "1920x1080"
                item.totalBytes = 1_040_000_000
                item.thumbnailURL = thumbnail
                item.status = state.0
                item.fractionCompleted = state.1
                item.speedBytesPerSecond = state.0 == .downloading ? 80_000_000 : nil
                item.errorMessage = state.0 == .failed ? "Unsupported URL" : nil
                return item
            }
        }
    }
#endif
