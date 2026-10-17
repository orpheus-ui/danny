import Foundation

/// What `DownloadManager` asks of yt-dlp. `YTDLPClient` is the real one; tests pass a
/// fake to check the manager's decisions without a network or a process.
nonisolated protocol DownloadEngine: Sendable {
    @concurrent
    func probe(url: URL, binaries: YTDLPClient.Binaries, extraArguments: [String]) async throws -> VideoMetadata

    @concurrent
    func version(binaries: YTDLPClient.Binaries) async -> String?

    func downloadStream(
        url: URL, into directory: URL, binaries: YTDLPClient.Binaries, extraArguments: [String],
    ) -> AsyncThrowingStream<DownloadEvent, Error>
}

extension YTDLPClient: DownloadEngine {}
