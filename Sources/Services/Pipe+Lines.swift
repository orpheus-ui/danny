import Foundation

nonisolated extension Pipe {
    /// The lines written to the pipe, as they arrive, read by the pipe's own handler.
    /// `FileHandle.bytes` reads every handle in turn on one queue, so one quiet yt-dlp
    /// (a cold start, a slow page) held back every other one's output, a download's
    /// progress included.
    var lines: AsyncStream<String> {
        let handle = fileHandleForReading
        let pending = PendingBytes()
        return AsyncStream { continuation in
            continuation.onTermination = { _ in handle.readabilityHandler = nil }
            handle.readabilityHandler = { handle in
                let chunk = handle.availableData
                for line in pending.lines(adding: chunk) {
                    continuation.yield(line)
                }
                if chunk.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.finish()
                }
            }
        }
    }

    /// Everything written to the pipe, once it closes.
    func text() async -> String {
        var text = ""
        for await line in lines {
            text += line + "\n"
        }
        return text
    }
}

/// What follows the last line break. A handle runs its handler one call at a time.
private final nonisolated class PendingBytes: @unchecked Sendable {
    private var bytes = Data()

    /// The lines `chunk` completes; an empty chunk, the end, flushes the rest.
    func lines(adding chunk: Data) -> [String] {
        bytes.append(chunk)
        var pieces = bytes.split(omittingEmptySubsequences: false) { $0 == 0x0A || $0 == 0x0D }
        bytes = chunk.isEmpty ? Data() : Data(pieces.removeLast())
        return pieces.filter { !$0.isEmpty }.compactMap { String(bytes: $0, encoding: .utf8) }
    }
}
