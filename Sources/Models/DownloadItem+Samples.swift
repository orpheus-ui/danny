#if DEBUG
    import Foundation

    extension DownloadItem {
        /// One item per state, matching the Figma cards. `-sample-queue` shows them.
        static var samples: [DownloadItem] {
            let thumbnail = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Images/sample-thumbnail.png")
            let states: [(ItemStatus, Double?)] = [
                (.downloading, 0.54), (.choosing, nil), (.resolving, nil), (.processing, nil),
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
                if state.0 == .choosing {
                    item.qualityOptions = [
                        QualityOption(choice: .video(maxHeight: 1080), label: "1080p", bytes: 340_000_000),
                        QualityOption(choice: .video(maxHeight: 720), label: "720p", bytes: 150_000_000),
                        QualityOption(choice: .video(maxHeight: 480), label: "480p", bytes: 70_000_000),
                        QualityOption(choice: .audio, label: "Audio", bytes: 9_000_000),
                    ]
                    item.choiceDeadline = Date().addingTimeInterval(8)
                }
                return item
            }
        }
    }
#endif
