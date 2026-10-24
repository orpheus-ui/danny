import CryptoKit
import Foundation
import OSLog

/// Keeps a current yt-dlp in Application Support, ahead of the bundled or
/// Homebrew copy. Sites change weekly and yt-dlp follows them, so a release of
/// Danny would otherwise carry a yt-dlp that ages until the next one.
///
/// A new release is installed only after its checksum list carries a valid
/// signature from yt-dlp's release key (bundled with Danny), its file matches the
/// SHA-256 in that list, and the binary runs and reports the expected version. The file is
/// renamed into place, so a download already running keeps the old one.
nonisolated struct YTDLPUpdater: Sendable {
    typealias Fetch = @Sendable (URL) async throws -> Data
    typealias VersionOf = @Sendable (URL) async -> String?
    typealias Verify = @Sendable (_ file: Data, _ signature: Data) -> Bool

    enum Outcome: Equatable {
        case current(String)
        case updated(String)
        case failed(String)
    }

    /// A finished check: what it found, and when.
    struct Check: Equatable {
        let outcome: Outcome
        let date: Date
    }

    private static let log = Logger(subsystem: "app.danny.desktop", category: "yt-dlp")
    private static let latestRelease = URL(string: "https://api.github.com/repos/yt-dlp/yt-dlp/releases/latest")!
    /// The universal macOS build, as yt-dlp names it in each release.
    static let assetName = "yt-dlp_macos"

    /// Where the managed copy lives: `~/Library/Application Support/Danny/bin`.
    static var managedDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent("Danny/bin", isDirectory: true)
    }

    static var managedBinary: URL { managedDirectory.appendingPathComponent("yt-dlp") }

    var directory = Self.managedDirectory
    var fetch: Fetch = Self.network
    var versionOf: VersionOf = { url in
        await YTDLPClient().version(binaries: .init(ytdlp: url, ffmpegDirectory: nil))
    }

    var isSigned: Verify = { file, signature in OpenPGPKey.ytdlp?.verifies(signature, of: file) ?? false }

    /// Installs the latest release when it is newer than `installed`, the version
    /// of the yt-dlp Danny uses now (nil when there is none).
    func update(from installed: String?) async -> Outcome {
        do {
            let release = try await latestTag()
            if let installed, !Self.isNewer(release, than: installed) {
                Self.log.notice("yt-dlp \(installed, privacy: .public) is current")
                return .current(installed)
            }
            try await install(release)
            Self.log.notice("yt-dlp updated to \(release, privacy: .public)")
            return .updated(release)
        } catch {
            Self.log.error("yt-dlp update failed: \(error.localizedDescription, privacy: .public)")
            return .failed(error.localizedDescription)
        }
    }

    private func latestTag() async throws -> String {
        try await JSONDecoder().decode(Release.self, from: fetch(Self.latestRelease)).tagName
    }

    private func install(_ release: String) async throws {
        let base = URL(string: "https://github.com/yt-dlp/yt-dlp/releases/download/\(release)/")!
        let sums = try await fetch(base.appendingPathComponent("SHA2-256SUMS"))
        let signature = try await fetch(base.appendingPathComponent("SHA2-256SUMS.sig"))
        guard isSigned(sums, signature) else {
            throw YTDLPError(message: "yt-dlp \(release)'s checksums aren't signed with yt-dlp's release key.")
        }
        guard let list = String(bytes: sums, encoding: .utf8), let expected = Self.checksum(
            of: Self.assetName,
            in: list,
        )
        else {
            throw YTDLPError(message: "yt-dlp \(release) lists no checksum for \(Self.assetName).")
        }
        let binary = try await fetch(base.appendingPathComponent(Self.assetName))
        guard Self.sha256(binary) == expected else {
            throw YTDLPError(message: "yt-dlp \(release) doesn't match its published checksum.")
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let staged = directory.appendingPathComponent(".yt-dlp-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: staged) }
        try binary.write(to: staged)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: staged.path)
        guard let reported = await versionOf(staged), reported == release else {
            throw YTDLPError(message: "yt-dlp \(release) didn't run on this Mac.")
        }
        let target = directory.appendingPathComponent("yt-dlp")
        guard rename(staged.path, target.path) == 0 else {
            throw YTDLPError(message: "Couldn't install yt-dlp \(release): \(String(cString: strerror(errno))).")
        }
        try Data(release.utf8).write(to: Self.versionFile(of: target), options: .atomic)
    }

    /// `managed` when it is installed and not older than `bundled`. Each copy's
    /// version sits beside it in `yt-dlp.version`: the updater writes the managed
    /// one, `scripts/fetch-dependencies.sh` the bundled one. Reading them spares
    /// launching both binaries at startup.
    static func managed(_ managed: URL, unlessOlderThan bundled: URL?) -> URL? {
        guard FileManager.default.isExecutableFile(atPath: managed.path) else { return nil }
        guard let bundled, let bundledVersion = version(beside: bundled) else { return managed }
        guard let managedVersion = version(beside: managed) else { return nil }
        return isNewer(bundledVersion, than: managedVersion) ? nil : managed
    }

    static func versionFile(of binary: URL) -> URL {
        binary.deletingLastPathComponent().appendingPathComponent(binary.lastPathComponent + ".version")
    }

    private static func version(beside binary: URL) -> String? {
        (try? String(contentsOf: versionFile(of: binary), encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Helpers

    static let network: Fetch = { url in
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let status = (response as? HTTPURLResponse)?.statusCode, status == 200 else {
            throw YTDLPError(message: "\(url.host() ?? "GitHub") didn't answer the update check.")
        }
        return data
    }

    /// yt-dlp versions are dates with an optional build number: 2026.08.19, 2026.08.19.1.
    static func isNewer(_ version: String, than other: String) -> Bool {
        let parts = { (text: String) in text.split(separator: ".").map { Int($0) ?? 0 } }
        let lhs = parts(version), rhs = parts(other)
        for index in 0 ..< max(lhs.count, rhs.count) {
            let left = index < lhs.count ? lhs[index] : 0
            let right = index < rhs.count ? rhs[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    /// The hex digest for `name` in a `sha256sum`-style list.
    static func checksum(of name: String, in sums: String) -> String? {
        for line in sums.split(whereSeparator: \.isNewline) {
            let fields = line.split(separator: " ", omittingEmptySubsequences: true)
            if fields.count == 2, fields[1] == name || fields[1] == "*\(name)" { return fields[0].lowercased() }
        }
        return nil
    }

    static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}

/// The one field read from GitHub's latest-release answer.
private nonisolated struct Release: Decodable {
    let tagName: String

    enum CodingKeys: String, CodingKey { case tagName = "tag_name" }
}
