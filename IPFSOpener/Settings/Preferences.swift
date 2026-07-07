import Foundation
import Observation

/// How an existing http(s) gateway URL should be handled.
enum ExistingURLHandling: String, CaseIterable, Identifiable {
    case passthrough
    case rewrite
    var id: String { rawValue }
    var label: String {
        switch self {
        case .passthrough: return "Open the URL as pasted"
        case .rewrite: return "Rewrite through my preferred gateway"
        }
    }
}

/// What the app does after successfully handing a URL to the browser.
enum AfterOpenBehavior: String, CaseIterable, Identifiable {
    case keepOpenAndSelect
    case keepOpenAndClear
    case closeWindow
    case quit
    var id: String { rawValue }
    var label: String {
        switch self {
        case .keepOpenAndSelect: return "Keep the window open and select the text"
        case .keepOpenAndClear: return "Keep the window open and clear the text"
        case .closeWindow: return "Close the window"
        case .quit: return "Quit IPFS Opener"
        }
    }
}

/// UserDefaults-backed, observable app preferences. No settings file to manage.
@Observable
final class Preferences {
    private let defaults: UserDefaults

    private enum Key {
        static let preferredGateway = "preferredGateway"
        static let existingURLHandling = "existingURLHandling"
        static let afterOpen = "afterOpen"
        static let warnOnPlainHttp = "warnOnPlainHttp"
        static let checkClipboardOnLaunch = "checkClipboardOnLaunch"
        // Reserved for the post-MVP fallback feature (persisted, not yet active).
        static let enableFallback = "enableFallback"
        static let fallbackGateways = "fallbackGateways"
        static let allowRemoteGatewayList = "allowRemoteGatewayList"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.preferredGateway = defaults.string(forKey: Key.preferredGateway) ?? GatewayConfig.defaultGateway
        self.existingURLHandling = ExistingURLHandling(rawValue: defaults.string(forKey: Key.existingURLHandling) ?? "") ?? .passthrough
        self.afterOpen = AfterOpenBehavior(rawValue: defaults.string(forKey: Key.afterOpen) ?? "") ?? .keepOpenAndSelect
        self.warnOnPlainHttp = defaults.object(forKey: Key.warnOnPlainHttp) as? Bool ?? true
        self.checkClipboardOnLaunch = defaults.object(forKey: Key.checkClipboardOnLaunch) as? Bool ?? true
        self.enableFallback = defaults.bool(forKey: Key.enableFallback)
        self.fallbackGateways = defaults.stringArray(forKey: Key.fallbackGateways) ?? GatewayConfig.defaultFallbacks
        self.allowRemoteGatewayList = defaults.bool(forKey: Key.allowRemoteGatewayList)
    }

    var preferredGateway: String { didSet { defaults.set(preferredGateway, forKey: Key.preferredGateway) } }
    var existingURLHandling: ExistingURLHandling { didSet { defaults.set(existingURLHandling.rawValue, forKey: Key.existingURLHandling) } }
    var afterOpen: AfterOpenBehavior { didSet { defaults.set(afterOpen.rawValue, forKey: Key.afterOpen) } }
    var warnOnPlainHttp: Bool { didSet { defaults.set(warnOnPlainHttp, forKey: Key.warnOnPlainHttp) } }
    var checkClipboardOnLaunch: Bool { didSet { defaults.set(checkClipboardOnLaunch, forKey: Key.checkClipboardOnLaunch) } }

    // Reserved for fallback (inactive in the MVP).
    var enableFallback: Bool { didSet { defaults.set(enableFallback, forKey: Key.enableFallback) } }
    var fallbackGateways: [String] { didSet { defaults.set(fallbackGateways, forKey: Key.fallbackGateways) } }
    var allowRemoteGatewayList: Bool { didSet { defaults.set(allowRemoteGatewayList, forKey: Key.allowRemoteGatewayList) } }

    /// Snapshot used by the resolver.
    var gatewayConfig: GatewayConfig {
        GatewayConfig(preferredGateway: preferredGateway,
                      rewriteExistingGatewayURLs: existingURLHandling == .rewrite,
                      fallbackEnabled: enableFallback,
                      fallbackGateways: fallbackGateways)
    }
}
