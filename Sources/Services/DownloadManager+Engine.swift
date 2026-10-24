import Foundation

// MARK: - Engine

/// What Danny asks yt-dlp before a download: the link's details, and the tools' versions.
extension DownloadManager {
    func toolVersions() async -> String {
        async let ytdlpVersion = client.version(binaries: binaries)
        let ffmpegInstalled = binaries.ffmpegDirectory != nil
        let ytdlpText = await (ytdlpVersion) ?? "not found"
        return "yt-dlp \(ytdlpText) · ffmpeg \(ffmpegInstalled ? "found" : "missing")"
    }

    /// Probes signed out first where the site prefers it, and again signed in when the
    /// link asks for it. `cookies` ends as the set the download uses.
    func probe(itemID: UUID, url: URL, signedIn cookies: inout [String]) async throws -> VideoMetadata? {
        let signedIn = cookies
        cookies = Self.firstTryCookies(for: url, signedIn: signedIn)
        do {
            return try await probe(itemID: itemID, url: url, cookies: cookies)
        } catch let error as YTDLPError where cookies != signedIn && DownloadItem.asksForSignIn(error.message) {
            cookies = signedIn
            return try await probe(itemID: itemID, url: url, cookies: cookies)
        }
    }

    /// Reads the link's details and puts them on the card. With the quality known,
    /// the probe lists the very files the download fetches. Nil when the card was
    /// cancelled or removed meanwhile.
    func probe(itemID: UUID, url: URL, cookies: [String]) async throws -> VideoMetadata? {
        let item = items.first(where: { $0.id == itemID })
        let preset = item?.quality ?? settings.quality.choice
        let presetArguments = item?.run?.format
            ?? preset.map { QualitySelection.arguments(for: $0, format: settings.format) } ?? []
        let arguments = await youTubeTokens.arguments(cookies + presetArguments, for: url)
        let metadata = try await client.probe(url: url, binaries: binaries, extraArguments: arguments)
        guard !Task.isCancelled, items.contains(where: { $0.id == itemID && $0.status == .resolving })
        else { return nil }
        // One change to the list, not one per field.
        updateItem(itemID) {
            $0.title = metadata.title.isEmpty ? $0.title : metadata.title
            $0.videoID = metadata.id
            $0.resolution = metadata.resolutionLabel
            $0.totalBytes = metadata.filesizeApprox
            $0.thumbnailURL = metadata.thumbnail.flatMap(URL.init(string:))
        }
        saveSoon()
        return metadata
    }
}
