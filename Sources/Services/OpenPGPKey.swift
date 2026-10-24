import CryptoKit
import Foundation
import Security

/// An RSA public key that checks detached OpenPGP signatures (RFC 4880) without
/// GnuPG. It reads only what yt-dlp publishes: a v4 RSA key, and v4 signatures of
/// a binary file over SHA-256, -384 or -512. Anything else fails the check.
nonisolated struct OpenPGPKey: Sendable {
    /// The key as PKCS #1 DER, the form Security reads.
    private let der: Data
    /// The modulus length in bytes, which a signature is padded to.
    private let size: Int

    /// yt-dlp's release key, `public.key` in its repository, bundled unchanged.
    /// Fingerprint AC0C BBE6 848D 6A87 3464 AF4E 57CF 6593 3B5A 7581.
    static let ytdlp: OpenPGPKey? = Bundle.main.url(forResource: "yt-dlp", withExtension: "asc", subdirectory: "Keys")
        .flatMap { try? String(contentsOf: $0, encoding: .utf8) }
        .flatMap(OpenPGPKey.init(armored:))

    /// Reads the primary key of an ASCII-armored public key block.
    init?(armored text: String) {
        guard let data = Self.dearmor(text), let key = Self.packets(data)?.first, key.tag == 6 else { return nil }
        var reader = Reader(key.body)
        // v4, a creation time, RSA (1), then the modulus and exponent.
        guard reader.byte() == 4, reader.bytes(4) != nil, reader.byte() == 1,
              let modulus = reader.mpi(), let exponent = reader.mpi(), !modulus.isEmpty
        else { return nil }
        der = Self.der(modulus: modulus, exponent: exponent)
        size = modulus.count
    }

    /// Whether any signature packet in `signature` is this key's over `message`.
    func verifies(_ signature: Data, of message: Data) -> Bool {
        guard let packets = Self.packets(signature) else { return false }
        return packets.contains { $0.tag == 2 && verifies(packet: $0.body, of: message) }
    }

    private func verifies(packet body: Data, of message: Data) -> Bool {
        var reader = Reader(body)
        // v4, a signature of a binary document (0), made with RSA (1).
        guard reader.byte() == 4, reader.byte() == 0, reader.byte() == 1,
              let hash = reader.byte(), let hashedLength = reader.int(2),
              let hashed = reader.bytes(hashedLength), Self.honors(subpackets: hashed),
              let unhashedLength = reader.int(2), reader.bytes(unhashedLength) != nil,
              reader.bytes(2) != nil, // the digest's first two bytes, a hint only
              let value = reader.mpi(), reader.isAtEnd, value.count <= size
        else { return false }

        // §5.2.4: the message, the signature's fields through its hashed subpackets, then a trailer.
        let fields = body.prefix(6 + hashedLength)
        let count = withUnsafeBytes(of: UInt32(fields.count).bigEndian) { Data($0) }
        let signed = message + fields + Data([4, 0xFF]) + count
        let digest: Data, algorithm: SecKeyAlgorithm
        switch hash {
        case 8: (digest, algorithm) = (Data(SHA256.hash(data: signed)), .rsaSignatureDigestPKCS1v15SHA256)
        case 9: (digest, algorithm) = (Data(SHA384.hash(data: signed)), .rsaSignatureDigestPKCS1v15SHA384)
        case 10: (digest, algorithm) = (Data(SHA512.hash(data: signed)), .rsaSignatureDigestPKCS1v15SHA512)
        default: return false
        }
        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeRSA, kSecAttrKeyClass: kSecAttrKeyClassPublic]
        guard let key = SecKeyCreateWithData(der as CFData, attributes as CFDictionary, nil) else { return false }
        // An MPI drops leading zero bytes; RSA wants the signature as long as the modulus.
        let padded = Data(count: size - value.count) + value
        return SecKeyVerifySignature(key, algorithm, digest as CFData, padded as CFData, nil)
    }

    /// False when the hashed subpackets say something this check can't honor:
    /// an expiry, or any critical one but the creation time (§5.2.3.1).
    static func honors(subpackets data: Data) -> Bool {
        var reader = Reader(data)
        while !reader.isAtEnd {
            guard let length = reader.length(), length > 0, let type = reader.byte(),
                  reader.bytes(length - 1) != nil
            else { return false }
            let critical = type & 0x80 != 0, kind = type & 0x7F
            if kind == 3 || (critical && kind != 2) { return false }
        }
        return true
    }

    // MARK: - Format

    private struct Packet {
        let tag: UInt8
        let body: Data
    }

    /// Splits OpenPGP packets (§4.2); nil when any is malformed or uses partial lengths.
    private static func packets(_ data: Data) -> [Packet]? {
        var reader = Reader(data), packets: [Packet] = []
        while !reader.isAtEnd {
            guard let ctb = reader.byte(), ctb & 0x80 != 0 else { return nil }
            let tag: UInt8, length: Int?
            if ctb & 0x40 != 0 {
                (tag, length) = (ctb & 0x3F, reader.length())
            } else {
                // Old format: the low two bits give a 1-, 2- or 4-byte length; 3 is indeterminate.
                (tag, length) = (ctb >> 2 & 0x0F, ctb & 3 < 3 ? reader.int(1 << Int(ctb & 3)) : nil)
            }
            guard let length, let body = reader.bytes(length) else { return nil }
            packets.append(Packet(tag: tag, body: body))
        }
        return packets
    }

    /// The bytes of an ASCII-armored block: base64 after the headers' blank line, up to the `=` checksum.
    private static func dearmor(_ text: String) -> Data? {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        guard let begin = lines.firstIndex(where: { $0.hasPrefix("-----BEGIN PGP") }),
              let blank = lines[begin...].firstIndex(of: "")
        else { return nil }
        let body = lines[(blank + 1)...].prefix { !$0.hasPrefix("=") && !$0.hasPrefix("-----") }
        return Data(base64Encoded: body.joined())
    }

    /// PKCS #1 RSAPublicKey: SEQUENCE { INTEGER modulus, INTEGER exponent }.
    private static func der(modulus: Data, exponent: Data) -> Data {
        func element(_ tag: UInt8, _ value: Data) -> Data {
            let count = withUnsafeBytes(of: UInt32(value.count).bigEndian, Array.init).drop { $0 == 0 }
            let length = value.count < 128 ? [UInt8(value.count)] : [0x80 | UInt8(count.count)] + count
            return Data([tag] + length) + value
        }
        // DER integers are signed, so a set top bit needs a zero byte in front.
        func integer(_ value: Data) -> Data { element(2, (value.first ?? 0) & 0x80 != 0 ? Data([0]) + value : value) }
        return element(0x30, integer(modulus) + integer(exponent))
    }
}

/// Reads big-endian fields from the front of some bytes; nil past the end.
private nonisolated struct Reader {
    private let data: Data
    private var offset = 0

    init(_ data: Data) { self.data = Data(data) } // a slice keeps its parent's indices; start from zero

    var isAtEnd: Bool { offset == data.count }

    mutating func bytes(_ count: Int) -> Data? {
        guard count >= 0, count <= data.count - offset else { return nil }
        defer { offset += count }
        return data.subdata(in: offset ..< offset + count)
    }

    mutating func byte() -> UInt8? { bytes(1)?.first }

    mutating func int(_ count: Int) -> Int? { bytes(count)?.reduce(0) { $0 << 8 | Int($1) } }

    /// A multiprecision integer (§3.2): a bit count, then that many bits.
    mutating func mpi() -> Data? { int(2).flatMap { bytes(($0 + 7) / 8) } }

    /// A new-format length (§4.2.2). Partial lengths (224–254) are refused: a key
    /// or signature never needs them, and as a subpacket length they'd be 8 KB+.
    mutating func length() -> Int? {
        guard let first = byte() else { return nil }
        switch first {
        case 0 ..< 192: return Int(first)
        case 192 ..< 224: return byte().map { (Int(first) - 192) << 8 + Int($0) + 192 }
        case 255: return int(4)
        default: return nil
        }
    }
}
