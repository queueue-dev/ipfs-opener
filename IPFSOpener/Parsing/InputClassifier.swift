import Foundation

/// The normalized result of interpreting a user-supplied IPFS input.
struct ParsedInput: Equatable {
    enum Namespace: String, Equatable { case ipfs, ipns }

    /// `ipfs` or `ipns`.
    var namespace: Namespace
    /// The CID (for `ipfs`) or name (for `ipns`).
    var identifier: String
    /// Path below the identifier, with no leading slash. May be empty.
    var path: String
    /// Query string without the leading `?`.
    var query: String?
    /// Fragment without the leading `#`.
    var fragment: String?
    /// Set when the input was already an http(s) gateway URL; opened as-is
    /// unless the user opted to rewrite through the preferred gateway.
    var passthroughURL: URL?
}

/// Plain-language failure reasons surfaced to the user.
enum InputError: Error, Equatable {
    case empty
    case unsupportedScheme(String)
    case invalidAddress
}

/// Classifies raw text into a `ParsedInput` or an `InputError`.
///
/// Supported forms: bare CID, `ipfs://`/`ipns://` URIs, `/ipfs/…` & `/ipns/…`
/// paths, existing http(s) gateway URLs (path-style or subdomain-style), and a
/// CID followed by a path/query/fragment.
enum InputClassifier {

    static func classify(_ raw: String) -> Result<ParsedInput, InputError> {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return .failure(.empty) }

        if let (scheme, rest) = detectScheme(trimmed) {
            let hasAuthority = rest.hasPrefix("//")
            let body = hasAuthority ? String(rest.dropFirst(2)) : rest
            switch scheme {
            case "ipfs": return parseNamespaced(.ipfs, body: body)
            case "ipns": return parseNamespaced(.ipns, body: body)
            case "http", "https":
                // A real gateway URL needs an authority component.
                return hasAuthority ? parseGatewayURL(trimmed) : .failure(.invalidAddress)
            default:
                return .failure(.unsupportedScheme(scheme))
            }
        }

        if trimmed.hasPrefix("/ipfs/") { return parseNamespaced(.ipfs, body: String(trimmed.dropFirst("/ipfs/".count))) }
        if trimmed.hasPrefix("/ipns/") { return parseNamespaced(.ipns, body: String(trimmed.dropFirst("/ipns/".count))) }
        if trimmed.hasPrefix("/") { return .failure(.invalidAddress) }

        // Otherwise: a bare CID, optionally with a path/query/fragment.
        return parseNamespaced(.ipfs, body: trimmed)
    }

    // MARK: - Helpers

    /// Detects a leading URI scheme (`scheme:`), returning the lowercased scheme
    /// and everything after the colon. Returns `nil` when there is no scheme
    /// before the first `/`, `?`, or `#` (i.e. it's a bare CID or path).
    private static func detectScheme(_ s: String) -> (scheme: String, rest: String)? {
        guard let first = s.first, first.isLetter else { return nil }
        var scheme = ""
        var idx = s.startIndex
        while idx < s.endIndex {
            let c = s[idx]
            if c == ":" {
                return (scheme.lowercased(), String(s[s.index(after: idx)...]))
            }
            if c == "/" || c == "?" || c == "#" { return nil }
            if c.isLetter || c.isNumber || c == "+" || c == "-" || c == "." {
                scheme.append(c)
                idx = s.index(after: idx)
                continue
            }
            return nil
        }
        return nil
    }

    private static func parseNamespaced(_ ns: ParsedInput.Namespace, body: String) -> Result<ParsedInput, InputError> {
        if body.isEmpty { return .failure(.invalidAddress) }

        let idEnd = body.firstIndex(where: { $0 == "/" || $0 == "?" || $0 == "#" }) ?? body.endIndex
        let identifier = String(body[..<idEnd])
        let (path, query, fragment) = splitSuffix(String(body[idEnd...]))

        if identifier.isEmpty { return .failure(.invalidAddress) }

        switch ns {
        case .ipfs:
            guard CIDParser.isValid(identifier) else { return .failure(.invalidAddress) }
        case .ipns:
            // IPNS names are CIDs or DNSLink domains; validate conservatively.
            if identifier.contains(where: { $0.isWhitespace }) { return .failure(.invalidAddress) }
        }

        return .success(ParsedInput(namespace: ns, identifier: identifier, path: path,
                                    query: query, fragment: fragment, passthroughURL: nil))
    }

    private static func parseGatewayURL(_ urlString: String) -> Result<ParsedInput, InputError> {
        guard let comps = URLComponents(string: urlString),
              let scheme = comps.scheme?.lowercased(), scheme == "http" || scheme == "https",
              let host = comps.host, !host.isEmpty,
              let url = URL(string: urlString) else {
            return .failure(.invalidAddress)
        }

        var namespace: ParsedInput.Namespace?
        var identifier: String?
        var subPath = ""

        // Path-style: https://host/ipfs/<cid>/<path…>
        let pathComps = comps.path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)
        if pathComps.count >= 2, pathComps[0] == "ipfs" || pathComps[0] == "ipns" {
            namespace = pathComps[0] == "ipfs" ? .ipfs : .ipns
            identifier = pathComps[1]
            subPath = pathComps.dropFirst(2).joined(separator: "/")
        } else {
            // Subdomain-style: https://<cid>.ipfs.<host>/<path…>
            let hostParts = host.split(separator: ".").map(String.init)
            if let nsIdx = hostParts.firstIndex(where: { $0 == "ipfs" || $0 == "ipns" }), nsIdx >= 1 {
                namespace = hostParts[nsIdx] == "ipfs" ? .ipfs : .ipns
                identifier = hostParts[0..<nsIdx].joined(separator: ".")
                subPath = comps.path.hasPrefix("/") ? String(comps.path.dropFirst()) : comps.path
            }
        }

        guard let ns = namespace, let id = identifier, !id.isEmpty else {
            return .failure(.invalidAddress) // http(s) URL that is not a recognized IPFS gateway
        }
        if ns == .ipfs, !CIDParser.isValid(id) { return .failure(.invalidAddress) }

        return .success(ParsedInput(namespace: ns, identifier: id, path: subPath,
                                    query: comps.percentEncodedQuery, fragment: comps.percentEncodedFragment,
                                    passthroughURL: url))
    }

    /// Splits a trailing `/path?query#fragment` chunk into its components.
    /// The path is returned without its leading slash.
    static func splitSuffix(_ suffix: String) -> (path: String, query: String?, fragment: String?) {
        var rest = suffix
        var fragment: String?
        if let hashIdx = rest.firstIndex(of: "#") {
            fragment = String(rest[rest.index(after: hashIdx)...])
            rest = String(rest[..<hashIdx])
        }
        var query: String?
        if let qIdx = rest.firstIndex(of: "?") {
            query = String(rest[rest.index(after: qIdx)...])
            rest = String(rest[..<qIdx])
        }
        if rest.hasPrefix("/") { rest.removeFirst() }
        return (rest, query, fragment)
    }
}
