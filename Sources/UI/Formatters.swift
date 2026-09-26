import Foundation

enum Format {
    static func size(_ bytes: Int64?) -> String? {
        guard let bytes, bytes > 0 else { return nil }
        let gb = Double(bytes) / 1_000_000_000
        if gb >= 1 {
            return gb >= 10 ? String(format: "%.0f GB", gb) : String(format: "%.2f GB", gb)
        }
        let mb = Double(bytes) / 1_000_000
        if mb >= 1 { return String(format: "%.0f MB", mb) }
        let kb = Double(bytes) / 1000
        return String(format: "%.0f KB", kb)
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
