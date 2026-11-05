import Foundation

public enum HotkeyAction: String, CaseIterable, Codable {
    case toggleLock
    case lockToCursorDisplay
    case lockToNextDisplay

    public var title: String {
        switch self {
        case .toggleLock: return "Toggle Dock lock"
        case .lockToCursorDisplay: return "Lock Dock to display under cursor"
        case .lockToNextDisplay: return "Lock Dock to next display"
        }
    }
}

/// `modifiers` uses Carbon modifier masks (cmdKey, optionKey, …) so it can be passed straight to RegisterEventHotKey.
public struct Hotkey: Codable, Equatable {
    public var keyCode: UInt32
    public var modifiers: UInt32
    public var label: String

    public init(keyCode: UInt32, modifiers: UInt32, label: String) {
        self.keyCode = keyCode
        self.modifiers = modifiers
        self.label = label
    }
}

public struct SetupLock: Codable, Equatable {
    public var displayUUID: String
    public var displayName: String
    public var setupDisplayNames: [String]

    public init(displayUUID: String, displayName: String, setupDisplayNames: [String]) {
        self.displayUUID = displayUUID
        self.displayName = displayName
        self.setupDisplayNames = setupDisplayNames
    }
}

public struct Config: Codable, Equatable {
    public var enabled: Bool
    public var resizeMaximizedWindows: Bool
    public var autoUpdate: Bool
    public var setups: [String: SetupLock]
    /// String keys keep the JSON hand-editable and tolerant of unknown actions.
    public var hotkeys: [String: Hotkey]

    public static let defaultHotkeys: [String: Hotkey] = {
        let ctrlOptCmd: UInt32 = 0x1000 | 0x0800 | 0x0100
        return [
            HotkeyAction.toggleLock.rawValue: Hotkey(keyCode: 2, modifiers: ctrlOptCmd, label: "⌃⌥⌘D"),
            HotkeyAction.lockToCursorDisplay.rawValue: Hotkey(keyCode: 37, modifiers: ctrlOptCmd, label: "⌃⌥⌘L"),
            HotkeyAction.lockToNextDisplay.rawValue: Hotkey(keyCode: 45, modifiers: ctrlOptCmd, label: "⌃⌥⌘N"),
        ]
    }()

    public init(
        enabled: Bool = true,
        resizeMaximizedWindows: Bool = true,
        autoUpdate: Bool = true,
        setups: [String: SetupLock] = [:],
        hotkeys: [String: Hotkey] = Config.defaultHotkeys
    ) {
        self.enabled = enabled
        self.resizeMaximizedWindows = resizeMaximizedWindows
        self.autoUpdate = autoUpdate
        self.setups = setups
        self.hotkeys = hotkeys
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        resizeMaximizedWindows = try c.decodeIfPresent(Bool.self, forKey: .resizeMaximizedWindows) ?? true
        autoUpdate = try c.decodeIfPresent(Bool.self, forKey: .autoUpdate) ?? true
        setups = try c.decodeIfPresent([String: SetupLock].self, forKey: .setups) ?? [:]
        hotkeys = try c.decodeIfPresent([String: Hotkey].self, forKey: .hotkeys) ?? Config.defaultHotkeys
    }

    public func hotkey(for action: HotkeyAction) -> Hotkey? {
        hotkeys[action.rawValue]
    }
}

public struct ConfigStore {
    public let url: URL

    public init(url: URL = ConfigStore.defaultURL) {
        self.url = url
    }

    public static var defaultURL: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DockAnchor", isDirectory: true)
            .appendingPathComponent("config.json")
    }

    public func load() throws -> Config {
        guard FileManager.default.fileExists(atPath: url.path) else { return Config() }
        return try JSONDecoder().decode(Config.self, from: Data(contentsOf: url))
    }

    public func save(_ config: Config) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(config).write(to: url, options: .atomic)
    }
}
