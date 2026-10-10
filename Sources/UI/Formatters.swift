import Foundation

enum Format {
    static func size(_ bytes: Int64?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        let gigabytes = Double(bytes) / 1_000_000_000
        if gigabytes >= 1 {
            return String(format: gigabytes >= 10 ? "%.0f GB" : "%.2f GB", gigabytes)
        }
        let megabytes = Double(bytes) / 1_000_000
        if megabytes >= 1 { return String(format: "%.0f MB", megabytes) }
        return String(format: "%.0f KB", Double(bytes) / 1000)
    }

    static func speed(_ bytesPerSecond: Double?) -> String? {
        guard let bytesPerSecond, bytesPerSecond > 0 else { return nil }
        let mbps = bytesPerSecond / 1_000_000
        if mbps >= 1 { return String(format: "%.0f MBps", mbps) }
        let kbps = bytesPerSecond / 1000
        if kbps >= 1 { return String(format: "%.0f KBps", kbps) }
        return String(format: "%.0f Bps", bytesPerSecond)
    }

    static func percent(_ fraction: Double?) -> String? {
        guard let fraction else { return nil }
        return "\(Int((fraction * 100).rounded()))%"
    }
}
