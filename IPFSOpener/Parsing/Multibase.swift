import Foundation

/// Decoders for the multibase encodings that appear in real-world CIDs.
///
/// We implement the encodings that CIDs actually use in practice: base32
/// (the default for CIDv1), base58btc (CIDv0 and some CIDv1), base16, base36
/// (used by some subdomain gateways), and base64 variants. Uncommon bases
/// (base2, base8, base10, …) are treated as unsupported — they essentially
/// never occur for CIDs.
enum Multibase {

    /// Result of attempting to decode a multibase-prefixed CIDv1 string.
    enum DecodeResult {
        /// Successfully decoded the payload bytes (excluding the multibase prefix).
        case decoded([UInt8])
        /// The prefix was recognized but the body was not valid for that base.
        case invalid
        /// The multibase prefix is not one we support.
        case unsupportedPrefix
    }

    static let base58btcAlphabet = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz"
    static let base36Alphabet = "0123456789abcdefghijklmnopqrstuvwxyz"

    /// Decodes the body of a CIDv1 string (a leading multibase prefix character
    /// followed by the encoded bytes).
    static func decodeCIDv1(_ string: String) -> DecodeResult {
        guard let prefix = string.first else { return .unsupportedPrefix }
        let body = String(string.dropFirst())
        let bytes: [UInt8]?
        switch prefix {
        case "b", "B": bytes = base32Decode(body.lowercased())          // RFC4648 base32, no padding
        case "f", "F": bytes = base16Decode(body.lowercased())          // hex
        case "z":      bytes = baseNDecode(body, alphabet: base58btcAlphabet) // base58btc
        case "k", "K": bytes = baseNDecode(body.lowercased(), alphabet: base36Alphabet) // base36
        case "m", "M": bytes = base64Decode(body, urlSafe: false)
        case "u", "U": bytes = base64Decode(body, urlSafe: true)
        default:       return .unsupportedPrefix
        }
        guard let decoded = bytes else { return .invalid }
        return .decoded(decoded)
    }

    // MARK: - Base decoders

    /// Big-integer style decode for base58/base36 given an alphabet.
    static func baseNDecode(_ input: String, alphabet: String) -> [UInt8]? {
        if input.isEmpty { return nil }
        let alpha = Array(alphabet)
        let base = alpha.count
        var map: [Character: Int] = [:]
        for (i, c) in alpha.enumerated() { map[c] = i }

        var result: [UInt8] = []
        for c in input {
            guard var carry = map[c] else { return nil }
            for j in 0..<result.count {
                carry += Int(result[j]) * base
                result[j] = UInt8(carry & 0xFF)
                carry >>= 8
            }
            while carry > 0 {
                result.append(UInt8(carry & 0xFF))
                carry >>= 8
            }
        }
        // Preserve leading "zero" digits as leading zero bytes.
        let zeroChar = alpha[0]
        for c in input {
            if c == zeroChar { result.append(0) } else { break }
        }
        return result.reversed()
    }

    /// RFC4648 base32 decode (lowercase alphabet, no padding).
    static func base32Decode(_ input: String) -> [UInt8]? {
        if input.isEmpty { return nil }
        let alphabet = "abcdefghijklmnopqrstuvwxyz234567"
        var map: [Character: Int] = [:]
        for (i, c) in alphabet.enumerated() { map[c] = i }

        var bits = 0
        var value = 0
        var out: [UInt8] = []
        for c in input {
            guard let v = map[c] else { return nil }
            value = (value << 5) | v
            bits += 5
            if bits >= 8 {
                bits -= 8
                out.append(UInt8((value >> bits) & 0xFF))
            }
        }
        return out
    }

    static func base16Decode(_ input: String) -> [UInt8]? {
        if input.isEmpty || input.count % 2 != 0 { return nil }
        var out: [UInt8] = []
        out.reserveCapacity(input.count / 2)
        var iterator = input.makeIterator()
        while let hi = iterator.next(), let lo = iterator.next() {
            guard let h = hi.hexDigitValue, let l = lo.hexDigitValue else { return nil }
            out.append(UInt8(h << 4 | l))
        }
        return out
    }

    static func base64Decode(_ input: String, urlSafe: Bool) -> [UInt8]? {
        if input.isEmpty { return nil }
        var s = input
        if urlSafe {
            s = s.replacingOccurrences(of: "-", with: "+")
                 .replacingOccurrences(of: "_", with: "/")
        }
        while s.count % 4 != 0 { s += "=" }
        guard let data = Data(base64Encoded: s) else { return nil }
        return [UInt8](data)
    }
}
