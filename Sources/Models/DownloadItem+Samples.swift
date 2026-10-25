#if DEBUG
    import Foundation

    extension DownloadItem {
        /// One item per state, matching the Figma cards. `-sample-queue` shows them.
        static var samples: [DownloadItem] {
            let thumbnail = artwork(1)
            let states: [(ItemStatus, Double?)] = [
                (.downloading, 0.54), (.paused, 0.59), (.choosing, nil), (.existing, nil), (.resolving, nil), (
                    .processing,
                    nil,
                ),
                (.finished, 1), (.failed, nil), (.queued, nil),
            ].reversed() // the list shows the newest first
            return states.enumerated().map { index, state in
                var item = DownloadItem(url: URL(string: "https://www.youtube.com/watch?v=sample\(index)")!)
                item.title = sampleTitles[state.0] ?? "Sample video"
                item.host = "youtube.com"
                item.resolution = "1920x1080"
                item.totalBytes = 1_040_000_000
                item.thumbnailURL = thumbnail
                item.status = state.0
                // The finished card is from earlier, so the list shows all three sections.
                if state.0 == .finished { item.addedAt = Date().addingTimeInterval(-2 * 86400) }
                item.fractionCompleted = state.1
                item.speedBytesPerSecond = state.0 == .downloading ? 80_000_000 : nil
                item.errorMessage = state.0 == .failed ? "ERROR: Unsupported URL: https://example.com/page" : nil
                // The thumbnail stands in for the video, so Open and Quick Look have a real file.
                item.filePath = state.0 == .finished ? thumbnail.path : nil
                if state.0 == .choosing {
                    item.qualityOptions = [
                        QualityOption(choice: .video(maxHeight: 1080), label: "1080p", bytes: 340_000_000),
                        QualityOption(choice: .video(maxHeight: 720), label: "720p", bytes: 150_000_000),
                        QualityOption(choice: .video(maxHeight: 480), label: "480p", bytes: 70_000_000),
                        QualityOption(choice: .audio, label: "Audio", bytes: 9_000_000),
                    ]
                    item.choiceDeadline = Date().addingTimeInterval(8)
                }
                if state.0 == .existing {
                    item.existingFile = ExistingFile(path: "/tmp/sample.mp4", resolution: "640x360")
                }
                return item
            }
        }

        /// One title per state; the downloading one is long, to show truncation.
        private static let sampleTitles: [ItemStatus: String] = [
            .downloading: "The complete guide to film photography, from loading a roll to scanning at home",
            .paused: "Building a tiny cabin in the woods",
            .choosing: "Street food tour of Bangkok",
            .existing: "Morning yoga, 20 minutes",
            .resolving: "Cello suite No. 1, live in Leipzig",
            .processing: "Formula Student: one season in 15 minutes",
            .finished: "Ocean waves for sleep, 8 hours",
            .failed: "A page with no video",
            .queued: "How maps get made",
        ]

        /// A believable queue for README screenshots. `-showcase-queue` shows it.
        static var showcase: [DownloadItem] {
            var items = [
                showcaseItem("Tokyo night walk in the rain", on: "youtube.com", "3840x2160", 2_400_000_000),
                showcaseItem("How a jet engine works, in 12 minutes", on: "vimeo.com", "1920x1080", 410_000_000),
                showcaseItem("Lo-fi beats to focus to, 3 hour mix", on: "youtube.com", nil, 180_000_000),
                showcaseItem("Sourdough from scratch: the whole process", on: "instagram.com", "1080x1920", 96_000_000),
                showcaseItem("Northern lights over Lofoten, timelapse", on: "x.com", "2560x1440", 640_000_000),
            ]
            let states: [(ItemStatus, Double?)] = [
                (.downloading, 0.62),
                (.downloading, 0.27),
                (.queued, nil),
                (.finished, 1),
                (.finished, 1),
            ]
            let speeds: [Double?] = [48_000_000, 21_000_000, nil, nil, nil]
            for index in items.indices {
                let artwork = artwork(index + 1)
                items[index].status = states[index].0
                items[index].fractionCompleted = states[index].1
                items[index].speedBytesPerSecond = speeds[index]
                items[index].thumbnailURL = artwork
                items[index].filePath = states[index].0 == .finished ? artwork.path : nil
                // Finished ones are from earlier days, so the list shows its sections.
                let days = states[index].0 == .finished ? Double(index - 2) : 0
                items[index].addedAt = Date().addingTimeInterval(-days * 86400 - Double(index) * 60)
            }
            return items
        }

        private static func showcaseItem(
            _ title: String,
            on host: String,
            _ resolution: String?,
            _ bytes: Int64,
        ) -> DownloadItem {
            var item = DownloadItem(url: URL(string: "https://\(host)/watch")!)
            item.title = title
            item.host = host
            item.resolution = resolution
            item.totalBytes = bytes
            return item
        }

        /// Abstract artwork made for the samples, so screenshots carry no third-party images.
        private static func artwork(_ number: Int) -> URL {
            URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("Resources/Images/showcase-\(number).jpg")
        }

        /// The sample in one state, to render a single card.
        static func sample(_ status: ItemStatus) -> DownloadItem {
            samples.first { $0.status == status }!
        }
    }
#endif
