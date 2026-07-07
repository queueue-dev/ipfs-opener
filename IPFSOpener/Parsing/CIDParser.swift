import Foundation

/// A structurally validated IPFS Content Identifier.
///
/// This is intentionally a *structural* parser, not a full multiformats table:
/// it verifies that the string decodes to a well-formed CID (version, codec,
/// multihash) without restricting which codec or hash function is used. That
/// keeps it small while still accepting unfamiliar-but-valid CID prefixes and
/// rejecting clearly malformed input.
struct CID: Equatable {
    enum Version: Equatable { case v0, v1 }

    let version: Version
    /// Multicodec content-type code (CIDv0 is implicitly dag-pb, `0x70`).
    let codec: UInt64
    /// Multihash function code (CIDv0 is implicitly sha2-256, `0x12`).
    let multihashCode: UInt64
    /// Multihash digest length in bytes.
    let digestLength: Int
}

enum CIDParser {

    /// Convenience predicate used by the input classifier.
    static func isValid(_ string: String) -> Bool {
        parse(string) != nil
    }

    /// Attempts to parse `string` as a CIDv0 or CIDv1. Returns `nil` when the
    /// input is empty, contains whitespace, or does not decode to a well-formed
    /// CID structure.
    static func parse(_ string: String) -> CID? {
        guard !string.isEmpty else { return nil }
        guard !string.contains(where: { $0.isWhitespace }) else { return nil }

        // CIDv0: base58btc with no multibase prefix, always begins "Qm",
        // decodes to a 34-byte sha2-256 multihash (0x12 0x20 + 32-byte digest).
        if string.hasPrefix("Qm") {
            guard let bytes = Multibase.baseNDecode(string, alphabet: Multibase.base58btcAlphabet),
                  bytes.count == 34,
                  bytes[0] == 0x12,
                  bytes[1] == 0x20 else { return nil }
            return CID(version: .v0, codec: 0x70, multihashCode: 0x12, digestLength: 32)
        }

        // CIDv1: <multibase-prefix><varint version><varint codec><multihash>.
        switch Multibase.decodeCIDv1(string) {
        case .decoded(let bytes):
            return parseV1(bytes)
        case .invalid, .unsupportedPrefix:
            return nil
        }
    }

    private static func parseV1(_ bytes: [UInt8]) -> CID? {
        var i = 0
        guard let version = Varint.read(bytes, &i), version == 1 else { return nil }
        guard let codec = Varint.read(bytes, &i) else { return nil }
        guard let mhCode = Varint.read(bytes, &i) else { return nil }
        guard let mhLen = Varint.read(bytes, &i) else { return nil }

        // The remaining bytes must be exactly the multihash digest.
        let remaining = bytes.count - i
        guard remaining == Int(mhLen) else { return nil }
        return CID(version: .v1, codec: codec, multihashCode: mhCode, digestLength: Int(mhLen))
    }
}
