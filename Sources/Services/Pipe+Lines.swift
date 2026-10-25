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

    /// The lines `chunk` completes; an empty chunk, the end, flushes the rest. Only new
    /// bytes are searched for a break, so `-J`'s one long line of JSON costs one pass.
    func lines(adding chunk: Data) -> [String] {
        let start = bytes.endIndex
        bytes.append(chunk)
        let end = chunk.isEmpty ? bytes.endIndex : bytes[start...].lastIndex(where: Self.isBreak).map { $0 + 1 }
        guard let end else { return [] }
        let complete = bytes[..<end]
        bytes = Data(bytes[end...])
        return complete.split(whereSeparator: Self.isBreak).compactMap { String(bytes: $0, encoding: .utf8) }
    }

    private static func isBreak(_ byte: UInt8) -> Bool { byte == 0x0A || byte == 0x0D }
}
