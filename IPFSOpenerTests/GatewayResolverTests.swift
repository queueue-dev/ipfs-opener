import Testing
import Foundation

struct GatewayResolverTests {

    private let cid = "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi"

    private func input(path: String = "", query: String? = nil, fragment: String? = nil,
                       passthrough: URL? = nil) -> ParsedInput {
        ParsedInput(namespace: .ipfs, identifier: cid, path: path,
                    query: query, fragment: fragment, passthroughURL: passthrough)
    }

    @Test func buildsPathStyleURL() throws {
        let result = GatewayResolver.buildURL(input(path: "images/art.png"), gateway: "https://dweb.link")
        let url = try #require(try result.get())
        #expect(url.absoluteString == "https://dweb.link/ipfs/\(cid)/images/art.png")
    }

    @Test func preservesQueryAndFragment() throws {
        let result = GatewayResolver.buildURL(input(path: "index.html", query: "mode=display", fragment: "section"),
                                              gateway: "https://dweb.link")
        let url = try #require(try result.get())
        #expect(url.absoluteString == "https://dweb.link/ipfs/\(cid)/index.html?mode=display#section")
    }

    @Test func expandsTemplate() throws {
        let result = GatewayResolver.buildURL(input(path: "a/b"), gateway: "https://ex.com/ipfs/{cid}{path}")
        let url = try #require(try result.get())
        #expect(url.absoluteString == "https://ex.com/ipfs/\(cid)/a/b")
    }

    @Test func passthroughOpensAsIs() async throws {
        let original = URL(string: "https://ipfs.io/ipfs/\(cid)/a")!
        let config = GatewayConfig(preferredGateway: "https://dweb.link", rewriteExistingGatewayURLs: false)
        let result = await GatewayResolver.resolve(input(path: "a", passthrough: original), config: config)
        #expect(try result.get() == original)
    }

    @Test func rewriteIgnoresPassthrough() async throws {
        let original = URL(string: "https://ipfs.io/ipfs/\(cid)/a")!
        let config = GatewayConfig(preferredGateway: "https://dweb.link", rewriteExistingGatewayURLs: true)
        let result = await GatewayResolver.resolve(input(path: "a", passthrough: original), config: config)
        let url = try #require(try result.get())
        #expect(url.absoluteString == "https://dweb.link/ipfs/\(cid)/a")
    }

    @Test func validatesGateways() {
        #expect(GatewayResolver.validateGateway("https://dweb.link"))
        #expect(GatewayResolver.validateGateway("https://ex.com/ipfs/{cid}{path}"))
        #expect(!GatewayResolver.validateGateway(""))
        #expect(!GatewayResolver.validateGateway("not a url"))
    }

    // MARK: - Fallback

    private func fallbackConfig(enabled: Bool) -> GatewayConfig {
        GatewayConfig(preferredGateway: "https://dweb.link",
                      rewriteExistingGatewayURLs: false,
                      fallbackEnabled: enabled,
                      fallbackGateways: ["https://ipfs.io", "https://4everland.io"])
    }

    @Test func fallbackDisabledNeverProbes() async throws {
        var probed = false
        let probe: ReachabilityProbe = { _ in probed = true; return true }
        let result = await GatewayResolver.resolve(input(), config: fallbackConfig(enabled: false), probe: probe)
        #expect(try result.get().host == "dweb.link")
        #expect(probed == false) // zero-network default is preserved
    }

    @Test func fallbackUsesPreferredWhenReachable() async throws {
        let probe: ReachabilityProbe = { _ in true }
        let result = await GatewayResolver.resolve(input(), config: fallbackConfig(enabled: true), probe: probe)
        #expect(try result.get().host == "dweb.link")
    }

    @Test func fallbackSkipsDownPreferred() async throws {
        // dweb.link down, ipfs.io up.
        let probe: ReachabilityProbe = { url in url.host == "ipfs.io" }
        let result = await GatewayResolver.resolve(input(path: "a"), config: fallbackConfig(enabled: true), probe: probe)
        let url = try #require(try result.get())
        #expect(url.absoluteString == "https://ipfs.io/ipfs/\(cid)/a")
    }

    @Test func fallbackProbesGatewayRootNotContentPath() async throws {
        var probedPaths: [String] = []
        let probe: ReachabilityProbe = { url in probedPaths.append(url.path); return url.host == "ipfs.io" }
        _ = await GatewayResolver.resolve(input(path: "deep/file.html"), config: fallbackConfig(enabled: true), probe: probe)
        #expect(probedPaths.allSatisfy { $0 == "/" }) // health-checks the root, not the CID
    }

    @Test func fallbackAllDownUsesPreferred() async throws {
        let probe: ReachabilityProbe = { _ in false }
        let result = await GatewayResolver.resolve(input(), config: fallbackConfig(enabled: true), probe: probe)
        #expect(try result.get().host == "dweb.link")
    }
}
