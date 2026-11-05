import AppKit
import DockAnchorCore

struct CLIError: Error {
    let message: String
}

let usage = """
usage: dockanchor <command> [--json]

commands:
  status              Show whether the app is running and where the Dock is locked
  list                List connected displays (* = locked for this screen setup)
  lock <display>      Lock the Dock to a display for the current screen setup and move it there
  unlock              Remove the lock for the current screen setup
  enable | disable    Turn Dock locking on or off globally
  toggle              Flip Dock locking on/off
  login [on|off|toggle|status]
                      Start DockAnchor at login (app must be running)
  setups              List saved screen setups

<display> is a 1-based index from `list`, a (partial) name, a UUID, or one of: main, cursor, next.
"""

let arguments = Array(CommandLine.arguments.dropFirst())
let wantsJSON = arguments.contains("--json")
let positional = arguments.filter { !$0.hasPrefix("--") }
let store = ConfigStore()

func loadConfig() throws -> Config {
    do { return try store.load() } catch {
        throw CLIError(message: "could not read \(store.url.path): \(error.localizedDescription)")
    }
}

func save(_ config: Config) throws {
    try store.save(config)
    IPC.post(IPC.reloadConfig)
}

func resolveDisplay(_ words: ArraySlice<String>, displays: [Display], config: Config) throws -> Display {
    let query = words.joined(separator: " ")
    guard !query.isEmpty else { throw CLIError(message: "missing <display>\n\n" + usage) }
    let locked = config.setups[Displays.setupKey(displays)]?.displayUUID
    do {
        return try Displays.resolve(query, in: displays, locked: locked, cursor: Displays.cursorLocation())
    } catch let error as DisplayQueryError {
        throw CLIError(message: error.description)
    }
}

func displayJSON(_ display: Display, index: Int, lockedUUID: String?) -> [String: Any] {
    [
        "index": index + 1,
        "name": display.name,
        "uuid": display.uuid,
        "main": display.isMain,
        "locked": display.uuid == lockedUUID,
        "frame": ["x": display.frame.minX, "y": display.frame.minY, "width": display.frame.width, "height": display.frame.height],
    ]
}

func printJSON(_ object: Any) throws {
    let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
    print(String(decoding: data, as: UTF8.self))
}

func warnIfAppNotRunning() {
    if !IPC.isAppRunning {
        FileHandle.standardError.write(Data("note: DockAnchor.app is not running; the change applies on next launch\n".utf8))
    }
}

func requestLaunchAtLogin(_ action: String) throws -> (state: String, error: String?) {
    guard IPC.isAppRunning else { throw CLIError(message: "DockAnchor.app must be running (open -a DockAnchor)") }
    var reply: [AnyHashable: Any]?
    let observer = DistributedNotificationCenter.default().addObserver(
        forName: IPC.launchAtLoginState, object: nil, queue: nil
    ) { reply = $0.userInfo ?? [:] }
    defer { DistributedNotificationCenter.default().removeObserver(observer) }

    IPC.post(IPC.launchAtLogin, userInfo: [IPC.actionKey: action])
    let deadline = Date().addingTimeInterval(3)
    while reply == nil && Date() < deadline {
        RunLoop.current.run(until: Date().addingTimeInterval(0.05))
    }
    guard let reply else { throw CLIError(message: "DockAnchor.app did not answer") }
    return (reply[IPC.stateKey] as? String ?? "unknown", reply[IPC.errorKey] as? String)
}

func run() throws {
    let displays = Displays.active()
    let setupKey = Displays.setupKey(displays)
    var config = try loadConfig()
    let lockedUUID = config.setups[setupKey]?.displayUUID
    let lockedDisplay = displays.first { $0.uuid == lockedUUID }

    switch positional.first ?? "help" {
    case "status":
        let orientation = DockOrientation.current()
        let dockDisplay = displays.first { DockMover.isDock(on: $0.frame) }
        if wantsJSON {
            try printJSON([
                "running": IPC.isAppRunning,
                "enabled": config.enabled,
                "orientation": orientation.rawValue,
                "lockedDisplay": lockedDisplay.map { d in
                    displayJSON(d, index: displays.firstIndex(of: d) ?? 0, lockedUUID: lockedUUID)
                } ?? NSNull(),
                "dockDisplay": dockDisplay?.name ?? NSNull(),
                "displayCount": displays.count,
            ])
        } else {
            print("app:       \(IPC.isAppRunning ? "running" : "not running")")
            print("locking:   \(config.enabled ? "enabled" : "disabled")")
            print("dock edge: \(orientation.rawValue)")
            print("setup:     \(displays.map(\.name).joined(separator: ", "))")
            print("locked to: \(lockedDisplay?.name ?? "nothing for this setup")")
            print("dock on:   \(dockDisplay?.name ?? "unknown")")
        }

    case "list":
        if wantsJSON {
            try printJSON(displays.enumerated().map { displayJSON($1, index: $0, lockedUUID: lockedUUID) })
        } else {
            for (i, d) in displays.enumerated() {
                let marker = d.uuid == lockedUUID ? "*" : " "
                let tags = [d.isMain ? "main" : nil, "\(Int(d.frame.width))x\(Int(d.frame.height))"].compactMap { $0 }
                print("\(marker) \(i + 1)  \(d.name)  (\(tags.joined(separator: ", ")))  \(d.uuid)")
            }
        }

    case "lock":
        let display = try resolveDisplay(positional.dropFirst(), displays: displays, config: config)
        config.setups[setupKey] = SetupLock(
            displayUUID: display.uuid,
            displayName: display.name,
            setupDisplayNames: displays.map(\.name)
        )
        config.enabled = true
        try save(config)
        warnIfAppNotRunning()
        IPC.post(IPC.moveDock, userInfo: [IPC.displayKey: display.uuid])
        print("Dock locked to \(display.name)")

    case "unlock":
        config.setups[setupKey] = nil
        try save(config)
        print("Dock unlocked for this screen setup")

    case "enable", "disable", "toggle":
        let command = positional[0]
        config.enabled = command == "toggle" ? !config.enabled : command == "enable"
        try save(config)
        warnIfAppNotRunning()
        print("Dock locking \(config.enabled ? "enabled" : "disabled")")

    case "login":
        var action = positional.dropFirst().first ?? "status"
        guard ["on", "off", "toggle", "status"].contains(action) else {
            throw CLIError(message: "usage: dockanchor login [on|off|toggle|status]")
        }
        if action == "toggle" {
            action = try requestLaunchAtLogin("status").state == "enabled" ? "off" : "on"
        }
        let reply = try requestLaunchAtLogin(action)
        if let error = reply.error { throw CLIError(message: "\(error) (launch at login: \(reply.state))") }
        print("Launch at login: \(reply.state)")

    case "setups":
        let entries = config.setups.sorted { $0.key < $1.key }
        if wantsJSON {
            try printJSON(entries.map { key, lock in
                ["current": key == setupKey, "displays": lock.setupDisplayNames, "lockedTo": lock.displayName, "displayUUID": lock.displayUUID]
            })
        } else if entries.isEmpty {
            print("No saved screen setups")
        } else {
            for (key, lock) in entries {
                let marker = key == setupKey ? "*" : " "
                print("\(marker) [\(lock.setupDisplayNames.joined(separator: ", "))] -> \(lock.displayName)")
            }
        }

    case "help", "-h":
        print(usage)

    default:
        throw CLIError(message: "unknown command \"\(positional[0])\"\n\n" + usage)
    }
}

do {
    try run()
    // Distributed notifications are delivered asynchronously; give distnoted a moment before exiting.
    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
} catch let error as CLIError {
    FileHandle.standardError.write(Data("error: \(error.message)\n".utf8))
    exit(1)
} catch {
    FileHandle.standardError.write(Data("error: \(error)\n".utf8))
    exit(1)
}
