import Foundation
import OSLog

/// One file of a merged download, as the probe lists it.
nonisolated struct RequestedFormat: Decodable {
    var formatID: String
    var filesize: Int64?
    var filesizeApprox: Int64?

    enum CodingKeys: String, CodingKey {
        case formatID = "format_id"
        case filesize
        case filesizeApprox = "filesize_approx"
    }
}

nonisolated struct VideoMetadata: Decodable {
    var id: String
    var title: String
    var thumbnail: String?
    var webpageURL: String?
    var width: Int?
    var height: Int?
    var duration: Double?
    var filesizeApprox: Int64?
    var extractor: String?
    /// The files a merged download fetches, such as video then audio.
    var requestedFormats: [RequestedFormat]?

    /// Approximate size of each file the download will fetch, by format id.
    var plannedFiles: [String: Int64] {
        var planned: [String: Int64] = [:]
        for format in requestedFormats ?? [] {
            planned[format.formatID] = format.filesize ?? format.filesizeApprox
        }
        return planned
    }

    /// Every format the site offers, for the quality options.
    var formats: [FormatInfo]?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case thumbnail
        case webpageURL = "webpage_url"
        case width
        case height
        case duration
        case filesizeApprox = "filesize_approx"
        case extractor
        case requestedFormats = "requested_formats"
        case formats
    }

    var resolutionLabel: String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        return "\(width)x\(height)"
    }
}

nonisolated enum DownloadEvent: Sendable {
    /// `file` is the format id being fetched; merged downloads fetch one file per format.
    case progress(downloaded: Int64, total: Int64?, speedBytesPerSecond: Double?, file: String? = nil)
    case outputFile(String)
    /// yt-dlp found the file already there and skipped the download.
    case alreadyDownloaded(String)
}

struct YTDLPError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

nonisolated struct YTDLPClient: Sendable {
    private static let log = Logger(subsystem: "app.danny.desktop", category: "yt-dlp")
    struct Binaries: Sendable {
        let ytdlp: URL
        let ffmpegDirectory: URL?
        /// The bundled QuickJS-ng, which yt-dlp needs to read YouTube's player (ADR-016).
        var jsRuntime: URL?

        static let missing = Binaries(ytdlp: URL(fileURLWithPath: "/usr/bin/false"), ffmpegDirectory: nil)

        /// Pins yt-dlp to the bundled runtime, so a run never depends on what else is
        /// installed. Without one, yt-dlp keeps its own default.
        var runtimeArguments: [String] {
            guard let jsRuntime else { return [] }
            return ["--no-js-runtimes", "--js-runtimes", "quickjs:\(jsRuntime.path)"]
        }
    }

    static func childProcessEnvironment() -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        let brewPaths = "/opt/homebrew/bin:/usr/local/bin"
        env["PATH"] = brewPaths + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        return env
    }

    static func locateBinaries() -> Binaries {
        // yt-dlp only: the progress template, format sorting and remux rules don't
        // exist in youtube-dl.
        // The copy Danny keeps current comes first (YTDLPUpdater), unless a newer
        // Danny brought a newer one.
        let managed = YTDLPUpdater.managed(YTDLPUpdater.managedBinary, unlessOlderThan: bundled("yt-dlp"))
        guard let ytdlp = managed ?? locate("yt-dlp") else { return .missing }
        return Binaries(
            ytdlp: ytdlp, ffmpegDirectory: locate("ffmpeg")?.deletingLastPathComponent(), jsRuntime: bundled("qjs"),
        )
    }

    private static func bundled(_ name: String) -> URL? {
        guard let url = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "bin"),
              FileManager.default.isExecutableFile(atPath: url.path) else { return nil }
        return url
    }

    private static func locate(_ name: String) -> URL? {
        if let bundled = bundled(name) { return bundled }
        let candidates = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)",
        ]
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        for dir in path.split(separator: ":") {
            let url = URL(fileURLWithPath: String(dir)).appendingPathComponent(name)
            if FileManager.default.isExecutableFile(atPath: url.path) { return url }
        }
        return nil
    }

    @concurrent
    func probe(url: URL, binaries: Binaries, extraArguments: [String] = []) async throws -> VideoMetadata {
        let output = try await runProcess(
            binaries.ytdlp,
            ["-J", "--no-playlist", "--skip-download"] + binaries.runtimeArguments + SystemProxy.current()
                + extraArguments + [url.absoluteString],
        )
        guard let data = output.data(using: .utf8),
              let metadata = try? JSONDecoder().decode(VideoMetadata.self, from: data)
        else {
            throw YTDLPError(message: "Danny couldn't find a downloadable video at this link.")
        }
        return metadata
    }

    @concurrent
    func version(binaries: Binaries) async -> String? {
        guard let output = try? await runProcess(binaries.ytdlp, ["--version"]) else { return nil }
        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func downloadStream(
        url: URL, into directory: URL, binaries: Binaries, extraArguments: [String] = [],
    ) -> AsyncThrowingStream<DownloadEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await runDownload(
                        url: url, into: directory, binaries: binaries,
                        extraArguments: extraArguments,
                    ) { event in
                        continuation.yield(event)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Split when yt-dlp moves behind the plugin protocol (M2; docs/backlog.md).
    @concurrent
    private func runDownload(
        url: URL, into directory: URL, binaries: Binaries, extraArguments: [String],
        onEvent: @escaping @Sendable (DownloadEvent) -> Void,
    ) async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let progressTemplate =
            // The exact size when yt-dlp has it, else its estimate (fragmented streams).
            "download:\u{40}P|%(progress.downloaded_bytes)s|%(progress.total_bytes,progress.total_bytes_estimate)s"
            + "|%(progress._speed_str)s|%(info.format_id)s"

        var arguments = Self.downloadArguments(in: directory, progressTemplate: progressTemplate)
        if let ffmpeg = binaries.ffmpegDirectory {
            arguments += ["--ffmpeg-location", ffmpeg.path]
        }
        arguments += binaries.runtimeArguments + SystemProxy.current() + extraArguments
        arguments.append(url.absoluteString)

        let process = Process()
        process.executableURL = binaries.ytdlp
        process.arguments = arguments
        process.environment = Self.childProcessEnvironment()

        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = stdout
        process.standardInput = FileHandle.nullDevice

        defer {
            if process.isRunning { process.terminate() }
        }

        var failureLines: [String] = []
        var outputPath: String?

        try await Self.running(process) {
            for try await line in stdout.fileHandleForReading.bytes.lines {
                if line.hasPrefix("FILE:") {
                    let path = String(line.dropFirst(5))
                    if !path.isEmpty { outputPath = path }
                    continue
                }
                if let event = Self.parseEvent(line) {
                    onEvent(event)
                } else if line.contains("ERROR") {
                    failureLines.append(line)
                } else if line.hasPrefix("WARNING") {
                    // Kept in the system log: they explain thin format lists (`log show
                    // --predicate 'subsystem == "app.danny.desktop"'`).
                    Self.log.warning("\(line, privacy: .public)")
                }
            }
        }

        process.waitUntilExit()

        if let outputPath {
            onEvent(.outputFile(outputPath))
        }

        guard process.terminationStatus == 0 else {
            throw YTDLPError(message: Self.meaningfulError(failureLines)
                ?? "yt-dlp exited with code \(process.terminationStatus).")
        }
    }

    static func downloadArguments(in directory: URL, progressTemplate: String) -> [String] {
        [
            "--newline", "--no-playlist", "--progress",
            "--print", "after_move:FILE:%(filepath)s",
            "--progress-template", progressTemplate,
            // Only speeds up fragmented streams (DASH, HLS); more than ~8 invites rate limits.
            "--concurrent-fragments", "8",
        ] + outputArguments(in: directory)
    }

    /// The speed limit setting as yt-dlp arguments: bytes per second, 0 for none.
    static func limitRateArguments(_ bytesPerSecond: Int) -> [String] {
        bytesPerSecond > 0 ? ["--limit-rate", String(bytesPerSecond)] : []
    }

    /// Where a download goes: `<name by template> [<id>]<suffix>.<ext>`. Extra arguments
    /// repeat it with the chosen template or a suffix, as in " (2)": yt-dlp takes the last `-o`.
    static func outputArguments(in directory: URL, template: FilenameTemplate = .title, suffix: String = "")
        -> [String]
    {
        ["-o", directory.appendingPathComponent("\(template.ytdlp)\(suffix).%(ext)s", isDirectory: false).path]
    }

    static func parseEvent(_ line: some StringProtocol) -> DownloadEvent? {
        alreadyDownloadedPath(line).map(DownloadEvent.alreadyDownloaded) ?? parseProgressLine(line)
    }

    /// The path in yt-dlp's `[download] <path> has already been downloaded` line.
    static func alreadyDownloadedPath(_ line: some StringProtocol) -> String? {
        let prefix = "[download] ", suffix = " has already been downloaded"
        guard line.hasPrefix(prefix), line.hasSuffix(suffix) else { return nil }
        let path = line.dropFirst(prefix.count).dropLast(suffix.count)
        return path.isEmpty ? nil : String(path)
    }

    static func parseProgressLine(_ line: some StringProtocol) -> DownloadEvent? {
        guard line.hasPrefix("@P|") else { return nil }
        let fields = line.dropFirst(3).split(separator: "|", omittingEmptySubsequences: false)
        guard fields.count == 3 || fields.count == 4 else { return nil }
        let downloaded = Int64(fields[0]) ?? 0
        let total = Int64(fields[1]).flatMap { $0 > 0 ? $0 : nil }
        let speed = parseSpeed(String(fields[2]))
        let file = fields.count == 4 && !fields[3].isEmpty && fields[3] != "NA" ? String(fields[3]) : nil
        return .progress(downloaded: downloaded, total: total, speedBytesPerSecond: speed, file: file)
    }

    static func parseSpeed(_ raw: String) -> Double? {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        guard let value = leadingNumber(trimmed), value >= 0 else { return nil }
        let lower = trimmed.lowercased()
        if lower.contains("gib") { return value * 1_073_741_824 }
        if lower.contains("mib") { return value * 1_048_576 }
        if lower.contains("kib") { return value * 1024 }
        if lower.contains("gb") { return value * 1_000_000_000 }
        if lower.contains("mb") { return value * 1_000_000 }
        if lower.contains("kb") { return value * 1000 }
        return value
    }

    private static func leadingNumber(_ text: String) -> Double? {
        var end = text.startIndex
        while end < text.endIndex,
              let scalar = text[end].unicodeScalars.first,
              scalar == "." || CharacterSet.decimalDigits.contains(scalar)
        {
            end = text.index(after: end)
        }
        guard end > text.startIndex else { return nil }
        return Double(text[text.startIndex ..< end].replacingOccurrences(of: ",", with: "."))
    }

    /// Launches `process` and runs `body` while it lives. Cancelling terminates it at
    /// once, not at its next line: yt-dlp can stay quiet for half a minute while it
    /// reads a page, and a removed card's download would otherwise finish anyway.
    private static func running<T>(_ process: Process, _ body: () async throws -> T) async throws -> T {
        try Task.checkCancellation()
        try process.run()
        do {
            return try await withTaskCancellationHandler(operation: body) {
                if process.isRunning { process.terminate() }
            }
        } catch {
            // A failed read leaves no one to wait for the process.
            if process.isRunning { process.terminate() }
            throw error
        }
    }

    @concurrent
    private static func readAll(_ pipe: Pipe) async -> String {
        let data = (try? pipe.fileHandleForReading.readToEnd()) ?? Data()
        return String(bytes: data, encoding: .utf8) ?? ""
    }

    private static func meaningfulError(_ lines: [String]) -> String? {
        lines.first?
            .replacingOccurrences(of: "ERROR: ", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    @concurrent
    private func runProcess(_ executable: URL, _ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = Self.childProcessEnvironment()
        process.standardInput = FileHandle.nullDevice
        let pipe = Pipe()
        let errors = Pipe()
        process.standardOutput = pipe
        process.standardError = errors

        // Read stderr alongside stdout, so neither pipe fills and stalls yt-dlp.
        var output = ""
        let errorText = try await Self.running(process) {
            async let errorText = Self.readAll(errors)
            for try await line in pipe.fileHandleForReading.bytes.lines {
                output += line + "\n"
            }
            return await errorText
        }
        process.waitUntilExit()
        let errorLines = errorText.split(separator: "\n").map(String.init)
        for line in errorLines where line.hasPrefix("WARNING") {
            Self.log.warning("\(line, privacy: .public)")
        }

        guard process.terminationStatus == 0 else {
            throw YTDLPError(message: Self.meaningfulError(errorLines.filter { $0.contains("ERROR") })
                ?? "yt-dlp exited with code \(process.terminationStatus).")
        }
        return output
    }
}

extension URL {
    var fileExistsAsExecutable: Bool {
        FileManager.default.isExecutableFile(atPath: path)
    }
}
