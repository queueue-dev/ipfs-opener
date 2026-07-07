import Testing

/// The parsing sources are compiled directly into this test target, so the
/// types are referenced without importing the app module.
struct CIDParserTests {

    @Test func acceptsCIDv0() {
        #expect(CIDParser.isValid("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"))
    }

    @Test func acceptsCIDv1Base32() {
        #expect(CIDParser.isValid("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"))
    }

    @Test func parsesCIDv0Structure() throws {
        let cid = try #require(CIDParser.parse("QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"))
        #expect(cid.version == .v0)
        #expect(cid.codec == 0x70)
        #expect(cid.multihashCode == 0x12)
        #expect(cid.digestLength == 32)
    }

    @Test func parsesCIDv1Structure() throws {
        let cid = try #require(CIDParser.parse("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"))
        #expect(cid.version == .v1)
        #expect(cid.digestLength == 32)
    }

    @Test func rejectsEmptyAndWhitespace() {
        #expect(!CIDParser.isValid(""))
        #expect(!CIDParser.isValid("   "))
        #expect(!CIDParser.isValid("bafy beig")) // internal space
    }

    @Test func rejectsGarbage() {
        #expect(!CIDParser.isValid("hello world"))
        #expect(!CIDParser.isValid("Qm")) // too short to be a real multihash
        #expect(!CIDParser.isValid("notacid"))
    }

    @Test func doesNotHardcodePrefixLengths() {
        // Truncated versions of otherwise valid CIDs must be rejected structurally.
        #expect(!CIDParser.isValid("bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbz"))
    }
}
