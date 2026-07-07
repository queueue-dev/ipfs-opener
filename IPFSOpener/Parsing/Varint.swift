import Foundation

/// Minimal unsigned LEB128 (protobuf-style) varint reader used by the CID parser.
///
/// Multiformats encode the CID version, multicodec, and multihash fields as
/// unsigned varints. This reader is deliberately tiny and dependency-free.
enum Varint {
    /// Reads a single unsigned varint from `bytes` starting at `index`.
    ///
    /// On success the value is returned and `index` is advanced past the varint.
    /// Returns `nil` if the buffer is truncated or the value would overflow `UInt64`.
    static func read(_ bytes: [UInt8], _ index: inout Int) -> UInt64? {
        var result: UInt64 = 0
        var shift: UInt64 = 0
        while index < bytes.count {
            let byte = bytes[index]
            index += 1
            // A 64-bit value uses at most 10 groups of 7 bits.
            if shift > 63 { return nil }
            let payload = UInt64(byte & 0x7F)
            if shift == 63 && payload > 1 { return nil } // would overflow bit 63
            result |= payload << shift
            if byte & 0x80 == 0 {
                return result
            }
            shift += 7
        }
        return nil // truncated
    }
}
