@testable import Danny
import Foundation
import Testing

/// Checked against a real yt-dlp release: 2026.08.19's `SHA2-256SUMS` and its
/// `SHA2-256SUMS.sig`, as published, in `Tests/Fixtures`.
struct OpenPGPKeyTests {
    private let sums: Data
    private let signature: Data

    init() throws {
        let release = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "Fixtures/yt-dlp-2026.08.19")
        sums = try Data(contentsOf: release.appending(path: "SHA2-256SUMS"))
        signature = try Data(contentsOf: release.appending(path: "SHA2-256SUMS.sig"))
    }

    private func changed(_ data: Data, at offset: Int) -> Data {
        var data = data
        data[offset] ^= 0x01
        return data
    }

    @Test
    func `the bundled key verifies a published yt-dlp release`() throws {
        let key = try #require(OpenPGPKey.ytdlp)
        #expect(key.verifies(signature, of: sums))
        #expect(YTDLPUpdater().isSigned(sums, signature))
    }

    @Test
    func `a changed checksum list fails`() throws {
        let key = try #require(OpenPGPKey.ytdlp)
        #expect(!key.verifies(signature, of: changed(sums, at: 0)))
        #expect(!key.verifies(signature, of: sums + Data("\n".utf8)))
        #expect(!key.verifies(signature, of: Data()))
    }

    @Test
    func `a changed or broken signature fails`() throws {
        let key = try #require(OpenPGPKey.ytdlp)
        #expect(!key.verifies(changed(signature, at: signature.count - 1), of: sums)) // the RSA value
        #expect(!key.verifies(changed(signature, at: 37), of: sums)) // its creation time, a hashed field
        #expect(!key.verifies(changed(signature, at: 4), of: sums)) // signature type: a text document
        #expect(!key.verifies(signature.dropLast(), of: sums))
        #expect(!key.verifies(signature + Data([0]), of: sums))
        #expect(!key.verifies(Data(), of: sums))
        #expect(!key.verifies(sums, of: sums))
    }

    @Test
    func `only a well-formed public key block reads`() {
        #expect(OpenPGPKey(armored: "") == nil)
        let block = "-----BEGIN PGP PUBLIC KEY BLOCK-----\n\nAAAA\n-----END PGP PUBLIC KEY BLOCK-----"
        #expect(OpenPGPKey(armored: block) == nil)
    }

    @Test
    func `hashed subpackets it can't honor void a signature`() {
        let created: [UInt8] = [5, 2, 0, 0, 0, 1]
        #expect(OpenPGPKey.honors(subpackets: Data(created)))
        #expect(OpenPGPKey.honors(subpackets: Data([5, 0x82, 0, 0, 0, 1]))) // critical creation time
        #expect(OpenPGPKey.honors(subpackets: Data(created + [2, 30, 1]))) // unknown, not critical
        #expect(!OpenPGPKey.honors(subpackets: Data(created + [2, 0x9E, 1]))) // unknown and critical
        #expect(!OpenPGPKey.honors(subpackets: Data(created + [5, 3, 0, 0, 0, 1]))) // an expiry
        #expect(!OpenPGPKey.honors(subpackets: Data([9, 2, 0, 0]))) // longer than its area
        #expect(!OpenPGPKey.honors(subpackets: Data([0]))) // no type
    }
}
