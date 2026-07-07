import Foundation

/// Snapshot of the gateway-related preferences, passed into the resolver so the
/// resolver stays free of UI/UserDefaults dependencies (and easily testable).
struct GatewayConfig: Equatable {
    /// Either a base host (`https://dweb.link`) or a template containing
    /// `{cid}` and optionally `{path}` placeholders.
    var preferredGateway: String
    /// When true, recognized http(s) gateway URLs are rewritten through the
    /// preferred gateway instead of being opened as-is.
    var rewriteExistingGatewayURLs: Bool
    /// When true, the resolver probes the preferred gateway and, if it's
    /// unreachable, falls through `fallbackGateways` before opening.
    var fallbackEnabled: Bool = false
    /// Ordered fallback gateways tried after the preferred one.
    var fallbackGateways: [String] = []

    static let defaultGateway = "https://dweb.link"
    static let defaultFallbacks = [
        "https://ipfs.io",
        "https://4everland.io",
        "https://ipfs.filebase.io",
    ]
}

enum GatewayError: Error, Equatable { case invalidGateway }

/// Async reachability check for a gateway. Injected into the resolver so the
/// selection logic can be unit-tested without real network access.
typealias ReachabilityProbe = (URL) async -> Bool

/// Turns a `ParsedInput` into the final `https` URL to hand to the browser, with
/// optional gateway fallback.
///
/// `resolve` is the single resolution choke point. With fallback disabled (the
/// default) it performs **no network activity** and returns the preferred
/// gateway's URL directly. With fallback enabled it probes each candidate
/// gateway's reachability and returns the first one that's up.
enum GatewayResolver {

    static func resolve(_ input: ParsedInput,
                        config: GatewayConfig,
                        probe: ReachabilityProbe = GatewayProbe.isReachable) async -> Result<URL, GatewayError> {
        // Existing gateway URL, opened verbatim unless the user chose to rewrite.
        if let passthrough = input.passthroughURL, !config.rewriteExistingGatewayURLs {
            return .success(passthrough)
        }

        // Ordered candidate gateways: preferred first, then fallbacks if enabled.
        var gateways = [config.preferredGateway]
        if config.fallbackEnabled { gateways += config.fallbackGateways }

        let urls: [URL] = gateways.compactMap { gateway in
            if case .success(let url) = buildURL(input, gateway: gateway) { return url }
            return nil
        }
        guard let preferred = urls.first else { return .failure(.invalidGateway) }

        // No fallback → return the preferred URL with zero network activity.
        guard config.fallbackEnabled, urls.count > 1 else { return .success(preferred) }

        // Probe each gateway's health (not the content) in order; open the first
        // one that's reachable. Probing the gateway root — rather than the CID —
        // avoids mistaking slow content retrieval for a down gateway.
        for url in urls {
            if await probe(healthURL(for: url)) { return .success(url) }
        }

        // Nothing reachable — best effort: hand the preferred URL to the browser.
        return .success(preferred)
    }

    /// Builds a path-style gateway URL (`https://host/ipfs/CID/path?query#fragment`),
    /// or expands a `{cid}`/`{path}` template.
    static func buildURL(_ input: ParsedInput, gateway: String) -> Result<URL, GatewayError> {
        let gw = gateway.trimmingCharacters(in: .whitespaces)
        if gw.isEmpty { return .failure(.invalidGateway) }

        let pathPart = input.path.isEmpty ? "" : "/\(input.path)"
        var urlString: String

        if gw.contains("{cid}") {
            urlString = gw
                .replacingOccurrences(of: "{cid}", with: input.identifier)
                .replacingOccurrences(of: "{path}", with: pathPart)
        } else {
            var base = gw
            if base.hasSuffix("/") { base.removeLast() }
            if !base.contains("://") { base = "https://" + base }
            urlString = "\(base)/\(input.namespace.rawValue)/\(input.identifier)\(pathPart)"
        }

        if let query = input.query, !query.isEmpty { urlString += "?\(query)" }
        if let fragment = input.fragment, !fragment.isEmpty { urlString += "#\(fragment)" }

        guard let url = URL(string: urlString),
              let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return .failure(.invalidGateway)
        }
        return .success(url)
    }

    /// Validates a user-entered gateway host/template before it is saved.
    static func validateGateway(_ gateway: String) -> Bool {
        let sample = ParsedInput(namespace: .ipfs,
                                 identifier: "bafybeigdyrzt5sfp7udm7hu76uh7y26nf3efuylqabf3oclgtqy55fbzdi",
                                 path: "a/b", query: nil, fragment: nil, passthroughURL: nil)
        if case .success = buildURL(sample, gateway: gateway) { return true }
        return false
    }

    /// The gateway's root URL (`scheme://host/`), used for health probing.
    private static func healthURL(for url: URL) -> URL {
        var comps = URLComponents()
        comps.scheme = url.scheme
        comps.host = url.host
        comps.port = url.port
        comps.path = "/"
        return comps.url ?? url
    }
}

/// Real-network reachability probe used by the resolver at runtime.
enum GatewayProbe {
    /// A gateway is "reachable" if it returns any HTTP response that is **not** a
    /// server error (5xx). Connection/DNS/timeout failures and 5xx count as down.
    /// A 4xx (including a content 404) means the gateway itself is up, so we do
    /// not switch away from it.
    static let isReachable: ReachabilityProbe = { url in
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 2.5
        request.cachePolicy = .reloadIgnoringLocalCacheData

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 2.5
        configuration.timeoutIntervalForResource = 3.0
        configuration.waitsForConnectivity = false

        do {
            let (_, response) = try await URLSession(configuration: configuration).data(for: request)
            guard let http = response as? HTTPURLResponse else { return false }
            return http.statusCode < 500
        } catch {
            return false
        }
    }
}
