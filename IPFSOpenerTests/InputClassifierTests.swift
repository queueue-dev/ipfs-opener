import Testing

struct InputClassifierTests {

    private let cidV0 = "QmYwAPJzv5CZsnA625s3Xf2nemtYgPpHdWEz79ojWnPbdG"
    private let cidV1 = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

    private func parsed(_ raw: String) -> ParsedInput? {
        if case .success(let p) = InputClassifier.classify(raw) { return p }
        return nil
    }

    @Test func bareCID() throws {
        let p = try #require(parsed(cidV0))
        #expect(p.namespace == .ipfs)
        #expect(p.identifier == cidV0)
        #expect(p.path.isEmpty)
        #expect(p.passthroughURL == nil)
    }

    @Test func ipfsURIWithPath() throws {
        let p = try #require(parsed("ipfs://\(cidV1)/path/to/file.html"))
        #expect(p.identifier == cidV1)
        #expect(p.path == "path/to/file.html")
    }

    @Test func ipfsPath() throws {
        let p = try #require(parsed("/ipfs/\(cidV0)/images/artwork.png"))
        #expect(p.identifier == cidV0)
        #expect(p.path == "images/artwork.png")
    }

    @Test func cidWithPathQueryFragment() throws {
        let p = try #require(parsed("\(cidV1)/index.html?mode=display#section"))
        #expect(p.identifier == cidV1)
        #expect(p.path == "index.html")
        #expect(p.query == "mode=display")
        #expect(p.fragment == "section")
    }

    @Test func pathStyleGatewayURLPassthrough() throws {
        let p = try #require(parsed("https://ipfs.io/ipfs/\(cidV0)/a/b"))
        #expect(p.identifier == cidV0)
        #expect(p.path == "a/b")
        #expect(p.passthroughURL != nil)
    }

    @Test func subdomainStyleGatewayURL() throws {
        let p = try #require(parsed("https://\(cidV1).ipfs.dweb.link"))
        #expect(p.identifier == cidV1)
        #expect(p.namespace == .ipfs)
        #expect(p.passthroughURL != nil)
    }

    @Test func rejectsEmpty() {
        #expect(InputClassifier.classify("   ") == .failure(.empty))
    }

    @Test func rejectsUnsupportedScheme() {
        #expect(InputClassifier.classify("ftp://example.com/file") == .failure(.unsupportedScheme("ftp")))
    }

    @Test func rejectsNonIPFSHTTPURL() {
        #expect(InputClassifier.classify("https://example.com/not/ipfs") == .failure(.invalidAddress))
    }

    @Test func rejectsGarbage() {
        #expect(InputClassifier.classify("just some words") == .failure(.invalidAddress))
    }
}
